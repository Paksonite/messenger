import AppKit

enum MainMenu {
    @MainActor
    static func make(target: AppDelegate, updater: Updater) -> NSMenu {
        let menu = NSMenu()

        let appMenu = submenu(in: menu, title: "Messenger")
        appMenu.addItem(withTitle: "About Messenger", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "Check for Updates…", action: #selector(Updater.checkForUpdates(_:)), keyEquivalent: "")
            .target = updater
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Messenger", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
            .keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Messenger", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = submenu(in: menu, title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Paste and Match Style", action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "V")
            .keyEquivalentModifierMask = [.command, .option, .shift]
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let viewMenu = submenu(in: menu, title: "View")
        viewMenu.addItem(withTitle: "Reload", action: #selector(WebViewController.reloadPage(_:)), keyEquivalent: "r")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(WebViewController.resetZoom(_:)), keyEquivalent: "0")
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(WebViewController.zoomIn(_:)), keyEquivalent: "=")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(WebViewController.zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
            .keyEquivalentModifierMask = [.command, .control]

        let windowMenu = submenu(in: menu, title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(.separator())
        let show = windowMenu.addItem(withTitle: "Messenger", action: #selector(AppDelegate.showMainWindow(_:)), keyEquivalent: "")
        show.target = target
        NSApp.windowsMenu = windowMenu

        return menu
    }

    @MainActor
    private static func submenu(in menu: NSMenu, title: String) -> NSMenu {
        let item = menu.addItem(withTitle: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        item.submenu = submenu
        return submenu
    }
}
