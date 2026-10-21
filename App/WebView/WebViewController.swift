import AppKit
import WebKit

@MainActor
final class WebViewController: NSViewController {
    let webView: WKWebView
    private let handler = WebViewHandler()
    private let badge = BadgeController()
    private var titleObservation: NSKeyValueObservation?

    init(bridge: NotificationBridge) {
        let configuration = WebViewConfigurationFactory.make(bridge: bridge)
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1100, height: 760), configuration: configuration)
        super.init(nibName: nil, bundle: nil)

        webView.navigationDelegate = handler
        webView.uiDelegate = handler
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = false
        webView.isInspectable = Self.isInspectorEnabled
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = webView
    }

    func load() {
        webView.load(URLRequest(url: NavigationPolicy.startURL))
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
}
