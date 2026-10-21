import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notificationBridge = NotificationBridge()
    private var mainWindowController: MainWindowController?
    private var updater: Updater?
    private var settingsWindowController: SettingsWindowController?

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else { return }

        // Two instances would both play sounds and post every notification twice.
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            Log.app.info("another instance is running (pid \(other.processIdentifier)), activating it")
            other.activate()
            NSApp.terminate(nil)
            return
        }

        Preferences.registerDefaults()
        let updater = Updater()
        self.updater = updater
        NSApp.mainMenu = MainMenu.make(target: self, updater: updater)

        UNUserNotificationCenter.current().delegate = self
        notificationBridge.requestAuthorization()
        notificationBridge.onActivate = { [weak self] in self?.showMainWindow(nil) }

        let controller = MainWindowController(bridge: notificationBridge)
        mainWindowController = controller
        controller.showWindow(nil)
        controller.webViewController.load()
        NSApp.activate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow(nil) }
        return true
    }

    // Closing the window only hides it, so the page keeps running and delivering notifications.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    @objc func showSettings(_ sender: Any?) {
        guard let updater else { return }
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(updater: updater)
        }
        settingsWindowController?.show()
    }

    @objc func showMainWindow(_ sender: Any?) {
        guard let window = mainWindowController?.window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    fileprivate var isMainWindowFocused: Bool {
        NSApp.isActive && (mainWindowController?.window?.isKeyWindow ?? false)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let focused = await MainActor.run { self.isMainWindowFocused }
        return focused ? [.list] : [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let userInfo = response.notification.request.content.userInfo
        if userInfo["kind"] as? String == Updater.notificationKind {
            await MainActor.run { self.updater?.checkForUpdates(nil) }
        } else if let id = userInfo["id"] as? String {
            await MainActor.run { self.notificationBridge.activate(notificationID: id) }
        }
    }
}
