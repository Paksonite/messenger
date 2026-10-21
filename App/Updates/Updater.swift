import AppKit
import Sparkle
import UserNotifications

/// Sparkle updates. Scheduled checks that find an update while the app is in the background
/// post a macOS notification ("gentle reminder") instead of opening a window.
@MainActor
final class Updater: NSObject {
    nonisolated static let notificationKind = "update"

    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
    }

    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }

    private func postReminder(version: String) {
        let content = UNMutableNotificationContent()
        content.title = "Messenger \(version) is available"
        content.body = "Click to install the update."
        content.userInfo = ["kind": Self.notificationKind]
        let request = UNNotificationRequest(identifier: Self.notificationKind, content: content, trigger: nil)
        // Completion handler form: UNUserNotificationCenter is not Sendable in older SDKs.
        UNUserNotificationCenter.current().add(request) { @Sendable error in
            if let error {
                Log.app.error("update reminder failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

extension Updater: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // Show Sparkle's window right away only when the check happened while the user was using the app.
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }
        Log.app.info("update \(update.displayVersionString, privacy: .public) available, posting reminder")
        postReminder(version: update.displayVersionString)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.notificationKind])
    }
}
