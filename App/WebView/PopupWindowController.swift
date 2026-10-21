import AppKit
import WebKit

/// Window for pages opened with `window.open`, e.g. audio and video calls.
@MainActor
final class PopupWindowController: NSWindowController, NSWindowDelegate {
    let webView: WKWebView
    var onClose: (() -> Void)?
    private var titleObservation: NSKeyValueObservation?

    init(configuration: WKWebViewConfiguration, windowFeatures: WKWindowFeatures, handler: WebViewHandler) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = handler
        webView.uiDelegate = handler

        let width = windowFeatures.width?.doubleValue ?? 960
        let height = windowFeatures.height?.doubleValue ?? 720
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Messenger"
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.center()

        super.init(window: window)
        window.delegate = self

        titleObservation = webView.observe(\.title, options: [.new]) { [weak window] webView, _ in
            MainActor.assumeIsolated {
                if let title = webView.title, !title.isEmpty { window?.title = title }
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func windowWillClose(_ notification: Notification) {
        webView.stopLoading()
        onClose?()
    }
}
