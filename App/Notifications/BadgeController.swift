import AppKit

/// Mirrors the unread count from the page title ("(3) Messenger") onto the Dock icon.
@MainActor
final class BadgeController {
    private(set) var count = 0
    var onIncrease: ((Int) -> Void)?

    /// Titles without a count that mean "nothing unread".
    nonisolated static let idleTitles: Set<String> = ["Messenger", "Facebook", "Messenger | Facebook"]

    /// Returns nil for titles that carry no count information, such as the
    /// "Jane sent a message" title Messenger flashes while something is unread.
    nonisolated static func unreadCount(fromTitle title: String?) -> Int? {
        guard let title else { return nil }
        if let match = title.firstMatch(of: /^\((\d+)\+?\)/) { return Int(match.1) }
        return idleTitles.contains(title.trimmingCharacters(in: .whitespaces)) ? 0 : nil
    }

    func update(title: String?) {
        guard let newCount = Self.unreadCount(fromTitle: title), newCount != count else { return }
        let increased = newCount > count
        count = newCount
        NSApp.dockTile.badgeLabel = newCount > 0 ? String(newCount) : nil
        Log.notifications.info("unread count: \(newCount)")
        if increased { onIncrease?(newCount) }
    }
}
