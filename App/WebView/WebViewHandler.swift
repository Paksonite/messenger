import AppKit
import WebKit

/// Navigation, UI and download handling shared by the main window and popup windows.
@MainActor
final class WebViewHandler: NSObject {
    private var popups: [PopupWindowController] = []

    private func popup(for webView: WKWebView) -> PopupWindowController? {
        popups.first { $0.webView === webView }
    }

    private func openExternally(_ url: URL) {
        Log.web.info("opening externally: \(url.absoluteString, privacy: .public)")
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

        Log.web.info("opening popup: \(navigationAction.request.url?.absoluteString ?? "", privacy: .public)")
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
        let isInternal = NavigationPolicy.internalDomains.contains {
            origin.host == $0 || origin.host.hasSuffix("." + $0)
        }
        decisionHandler(isInternal ? .grant : .deny)
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
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
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
        let destination = Self.uniqueURL(in: directory, for: suggestedFilename)
        Log.web.info("downloading to \(destination.path, privacy: .public)")
        return destination
    }

    func downloadDidFinish(_ download: WKDownload) {
        Log.web.info("download finished")
    }

    func download(_ download: WKDownload, didFailWithError error: any Error, resumeData: Data?) {
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
