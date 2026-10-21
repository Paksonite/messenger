import AppKit

enum MainMenu {
    @MainActor
    static func make(target: AppDelegate, updater: Updater) -> NSMenu {
        let menu = NSMenu()

        let appMenu = submenu(in: menu, title: "Messenger")
        appMenu.addItem(withTitle: String(localized: "About Messenger"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: String(localized: "Check for Updates…"), action: #selector(Updater.checkForUpdates(_:)), keyEquivalent: "")
            .target = updater
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Settings…"), action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
            .target = target
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Hide Messenger"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: String(localized: "Hide Others"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
            .keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: String(localized: "Show All"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Quit Messenger"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = submenu(in: menu, title: String(localized: "Edit"))
        editMenu.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: String(localized: "Paste and Match Style"), action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "V")
            .keyEquivalentModifierMask = [.command, .option, .shift]
        editMenu.addItem(withTitle: String(localized: "Delete"), action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let viewMenu = submenu(in: menu, title: String(localized: "View"))
        viewMenu.addItem(withTitle: String(localized: "Reload"), action: #selector(WebViewController.reloadPage(_:)), keyEquivalent: "r")
        viewMenu.addItem(withTitle: String(localized: "Back"), action: #selector(WebViewController.goBack(_:)), keyEquivalent: "[")
        viewMenu.addItem(withTitle: String(localized: "Forward"), action: #selector(WebViewController.goForward(_:)), keyEquivalent: "]")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: String(localized: "Actual Size"), action: #selector(WebViewController.resetZoom(_:)), keyEquivalent: "0")
        viewMenu.addItem(withTitle: String(localized: "Zoom In"), action: #selector(WebViewController.zoomIn(_:)), keyEquivalent: "=")
        viewMenu.addItem(withTitle: String(localized: "Zoom Out"), action: #selector(WebViewController.zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: String(localized: "Enter Full Screen"), action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
            .keyEquivalentModifierMask = [.command, .control]

        let chatsMenu = submenu(in: menu, title: String(localized: "Chats"))
        chatsMenu.addItem(withTitle: String(localized: "New Message"), action: #selector(WebViewController.newMessage(_:)), keyEquivalent: "n")
        chatsMenu.addItem(withTitle: String(localized: "Search"), action: #selector(WebViewController.focusSearch(_:)), keyEquivalent: "f")
        chatsMenu.addItem(.separator())
        for index in 1...9 {
            let item = chatsMenu.addItem(
                withTitle: String(localized: "Chat \(index)"),
                action: #selector(WebViewController.openChat(_:)),
                keyEquivalent: String(index)
            )
            item.tag = index
            // Only the first is listed; ⌘2…⌘9 work through their hidden items.
            item.isHidden = index > 1
            item.allowsKeyEquivalentWhenHidden = true
        }

        let windowMenu = submenu(in: menu, title: String(localized: "Window"))
        windowMenu.addItem(withTitle: String(localized: "Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: String(localized: "Zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
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
