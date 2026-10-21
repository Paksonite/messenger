import AppKit

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private static let frameName = "MainWindow"

    let webViewController: WebViewController

    init(bridge: NotificationBridge) {
        webViewController = WebViewController(bridge: bridge)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Messenger"
        window.backgroundColor = .windowBackgroundColor
        window.minSize = NSSize(width: 480, height: 400)
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentViewController = webViewController
        if !window.setFrameUsingName(Self.frameName) {
            window.setContentSize(NSSize(width: 1100, height: 760))
            window.center()
        }
        window.setFrameAutosaveName(Self.frameName)

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
