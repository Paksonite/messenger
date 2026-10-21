import AppKit

/// Mirrors the unread count from the page title ("(3) Messenger") onto the Dock icon.
@MainActor
final class BadgeController {
    private(set) var count = 0

    nonisolated static func unreadCount(fromTitle title: String?) -> Int {
        guard let title, let match = title.firstMatch(of: /^\((\d+)\+?\)/) else { return 0 }
        return Int(match.1) ?? 0
    }

    func update(title: String?) {
        let newCount = Self.unreadCount(fromTitle: title)
        guard newCount != count else { return }
        count = newCount
        NSApp.dockTile.badgeLabel = newCount > 0 ? String(newCount) : nil
        Log.notifications.debug("unread count: \(newCount)")
    }
}
