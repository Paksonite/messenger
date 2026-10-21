import AppKit
import WebKit

/// Delays when quitting: time for Messenger to react to the hidden page, then to send what it queued on unload.
private enum QuitTiming {
    static let afterHiding: Duration = .milliseconds(400)
    static let afterUnloading: Duration = .milliseconds(800)
}

@MainActor
final class WebViewController: NSViewController {
    private static let lastConversationKey = "LastConversationURL"

    let webView: WKWebView
    private let handler = WebViewHandler()
    private let badge = BadgeController()
    private let spinner = NSProgressIndicator()
    private var titleObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?
    private var loadingObservation: NSKeyValueObservation?

    init(bridge: NotificationBridge) {
        let configuration = WebViewConfigurationFactory.make(bridge: bridge)
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1100, height: 760), configuration: configuration)
        super.init(nibName: nil, bundle: nil)

        webView.navigationDelegate = handler
        webView.uiDelegate = handler
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = false
        webView.isInspectable = Self.isInspectorEnabled
        // Show the window background (dark in dark mode) instead of a white flash until the page paints.
        webView.setValue(false, forKey: "drawsBackground")
        bridge.webView = webView
        badge.onIncrease = { [weak bridge] count in bridge?.unreadCountIncreased(to: count) }

        titleObservation = webView.observe(\.title, options: [.initial, .new]) { [weak self, weak bridge] webView, _ in
            MainActor.assumeIsolated {
                if Log.isVerbose {
                    Log.web.info("title: \(webView.title ?? "", privacy: .public)")
                }
                bridge?.titleChanged(webView.title)
                self?.badge.update(title: webView.title)
            }
        }
        // Also fires for Messenger's in-page navigation (pushState), so the last chat is always current.
        urlObservation = webView.observe(\.url, options: [.new]) { webView, _ in
            MainActor.assumeIsolated {
                if let url = webView.url, NavigationPolicy.isConversation(url) {
                    UserDefaults.standard.set(url.absoluteString, forKey: Self.lastConversationKey)
                }
            }
        }
        loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
            MainActor.assumeIsolated {
                guard let self, !webView.isLoading else { return }
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
                self.loadingObservation = nil
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let container = NSView(frame: webView.frame)
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)

        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        spinner.startAnimation(nil)

        view = container
    }

    /// Opens the last conversation, or Messenger's start page.
    func load() {
        let saved = UserDefaults.standard.string(forKey: Self.lastConversationKey)
        webView.load(URLRequest(url: NavigationPolicy.launchURL(lastConversation: saved)))
    }

    /// Hides the window, then unloads the page, giving Messenger the `visibilitychange` and `pagehide`
    /// events a closing browser tab gets. Messenger sends queued work such as read receipts on those;
    /// without them, a chat read just before ⌘Q came back unread on the next launch.
    func unloadPage() async {
        view.window?.orderOut(nil)
        try? await Task.sleep(for: QuitTiming.afterHiding)
        webView.load(URLRequest(url: URL(string: "about:blank")!))
        try? await Task.sleep(for: QuitTiming.afterUnloading)
    }

    /// Always on in Debug; in Release enable with
    /// `defaults write pl.paksonite.messenger WebInspectorEnabled -bool true`.
    private static var isInspectorEnabled: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: "WebInspectorEnabled")
        #endif
    }

    private func runShortcut(_ call: String) {
        view.window?.makeFirstResponder(webView)
        webView.evaluateJavaScript("window.__messengerBridge?.\(call)") { result, error in
            if let error {
                Log.web.error("shortcut \(call, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.web.info("shortcut \(call, privacy: .public): \(result as? String ?? "no result", privacy: .public)")
            }
        }
    }

    // MARK: - Menu actions

    @objc func reloadPage(_ sender: Any?) {
        webView.reload()
    }

    @objc func resetZoom(_ sender: Any?) {
        webView.pageZoom = 1
    }

    @objc func zoomIn(_ sender: Any?) {
        webView.pageZoom = min(webView.pageZoom + 0.1, 3)
    }

    @objc func zoomOut(_ sender: Any?) {
        webView.pageZoom = max(webView.pageZoom - 0.1, 0.5)
    }

    @objc func goBack(_ sender: Any?) {
        webView.goBack()
    }

    @objc func goForward(_ sender: Any?) {
        webView.goForward()
    }

    /// ⌘1…⌘9: the menu item's tag is the position in the chat list.
    @objc func openChat(_ sender: NSMenuItem) {
        runShortcut("openChat(\(sender.tag))")
    }

    @objc func newMessage(_ sender: Any?) {
        runShortcut("newMessage()")
    }

    @objc func focusSearch(_ sender: Any?) {
        runShortcut("focusSearch()")
    }
}

extension WebViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(goBack(_:)): webView.canGoBack
        case #selector(goForward(_:)): webView.canGoForward
        default: true
        }
    }
}
