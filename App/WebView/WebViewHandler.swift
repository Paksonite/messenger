import AppKit
import WebKit

/// Navigation, UI and download handling shared by the main window and popup windows.
@MainActor
final class WebViewHandler: NSObject {
    private var popups: [PopupWindowController] = []
    /// Destination and source of each running download, for quarantining the file when it finishes.
    private var downloads: [ObjectIdentifier: (file: URL, source: URL?)] = [:]

    private func popup(for webView: WKWebView) -> PopupWindowController? {
        popups.first { $0.webView === webView }
    }

    private func openExternally(_ url: URL) {
        Log.web.info("opening externally: \(url.absoluteString, privacy: .private)")
        NSWorkspace.shared.open(url)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewHandler: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        if navigationAction.shouldPerformDownload { return .download }
        guard let url = navigationAction.request.url else { return .allow }

        switch NavigationPolicy.decide(url, isMainFrame: navigationAction.targetFrame?.isMainFrame ?? true) {
        case .allow:
            return .allow
        case .openExternally(let target):
            openExternally(target)
            // A popup that only existed to open an external link has nothing to show.
            if let popup = popup(for: webView), webView.url == nil || webView.url?.absoluteString == "about:blank" {
                popup.close()
            }
            return .cancel
        case .block:
            Log.web.error("blocked top-level \(url.scheme ?? "", privacy: .public): navigation")
            return .cancel
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        navigationResponse.canShowMIMEType ? .allow : .download
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Log.web.error("web content process terminated, reloading")
        webView.reload()
    }
}

// MARK: - WKUIDelegate

extension WebViewHandler: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url,
           case .openExternally(let target) = NavigationPolicy.decide(url, isMainFrame: true) {
            openExternally(target)
            return nil
        }

        if let url = navigationAction.request.url, NavigationPolicy.decide(url, isMainFrame: true) == .block {
            return nil
        }
        Log.web.info("opening popup: \(navigationAction.request.url?.absoluteString ?? "", privacy: .private)")
        let popup = PopupWindowController(configuration: configuration, windowFeatures: windowFeatures, handler: self)
        popup.onClose = { [weak self, weak popup] in
            self?.popups.removeAll { $0 === popup }
        }
        popups.append(popup)
        popup.showWindow(nil)
        return popup.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        popup(for: webView)?.close()
    }

    // Completion handler form: its async name differs between SDK versions.
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void
    ) {
        decisionHandler(NavigationPolicy.isInternal(host: origin.host) ? .grant : .deny)
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo
    ) async -> [URL]? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        let response = if let window = webView.window {
            await panel.beginSheetModal(for: window)
        } else {
            panel.runModal()
        }
        return response == .OK ? panel.urls : nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async {
        guard Self.canShowDialog(from: frame) else { return }
        let alert = NSAlert()
        alert.messageText = message
        _ = await Self.present(alert, in: webView)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async -> Bool {
        guard Self.canShowDialog(from: frame) else { return false }
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: String(localized: "OK"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return await Self.present(alert, in: webView) == .alertFirstButtonReturn
    }

    /// Only Messenger's own page may show dialogs; an embedded frame could otherwise block the app.
    private static func canShowDialog(from frame: WKFrameInfo) -> Bool {
        frame.isMainFrame && NavigationPolicy.isInternal(host: frame.securityOrigin.host)
    }

    /// A sheet on the page's window, so other windows stay usable.
    private static func present(_ alert: NSAlert, in webView: WKWebView) async -> NSApplication.ModalResponse {
        if let window = webView.window {
            return await alert.beginSheetModal(for: window)
        }
        return alert.runModal()
    }
}

// MARK: - WKDownloadDelegate

extension WebViewHandler: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String
    ) async -> URL? {
        let directory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        // Only the file name: a suggested name must not point outside the Downloads folder.
        let filename = (suggestedFilename as NSString).lastPathComponent
        let destination = Self.uniqueURL(in: directory, for: filename.isEmpty ? "download" : filename)
        downloads[ObjectIdentifier(download)] = (destination, download.originalRequest?.url)
        Log.web.info("downloading to \(destination.path, privacy: .private)")
        return destination
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let (file, source) = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        do {
            let wasQuarantined = try Quarantine.mark(file, downloadedFrom: source)
            Log.web.info("download finished, quarantine \(wasQuarantined ? "set by WebKit" : "added", privacy: .public)")
        } catch {
            Log.web.error("could not quarantine download: \(error.localizedDescription, privacy: .public)")
        }
    }

    func download(_ download: WKDownload, didFailWithError error: any Error, resumeData: Data?) {
        downloads.removeValue(forKey: ObjectIdentifier(download))
        Log.web.error("download failed: \(error.localizedDescription, privacy: .public)")
    }

    private static func uniqueURL(in directory: URL, for filename: String) -> URL {
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var candidate = directory.appending(path: filename)
        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            candidate = directory.appending(path: name)
            index += 1
        }
        return candidate
    }
}
