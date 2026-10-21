import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(updater: Updater) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(updater: updater)))
        window.title = String(localized: "Settings")
        window.styleMask = [.titled, .closable]
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
