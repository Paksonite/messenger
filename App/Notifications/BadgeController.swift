import AppKit

/// Mirrors the unread count from the page title ("(3) Messenger") onto the Dock icon.
///
/// Messenger may mark a message read when its chat is open in the hidden window, yet keep flashing
/// "Jane sent a message" in the title. While that attention title flashes, the badge shows at least 1.
@MainActor
final class BadgeController {
    private(set) var count = 0
    var onIncrease: ((Int) -> Void)?

    /// Titles without a count that mean "nothing unread".
    nonisolated static let idleTitles: Set<String> = ["Messenger", "Facebook", "Messenger | Facebook"]
    /// Messenger alternates titles every ~1.5 s; attention counts as over after a few silent seconds.
    private static let attentionTimeout: Duration = .seconds(4)

    private var titleCount = 0
    private var lastAttention: ContinuousClock.Instant?
    private var expiryTask: Task<Void, Never>?

    /// Returns nil for titles that carry no count information, such as the
    /// "Jane sent a message" title Messenger flashes while something is unread.
    nonisolated static func unreadCount(fromTitle title: String?) -> Int? {
        guard let title else { return nil }
        if let match = title.firstMatch(of: /^\((\d+)\+?\)/) { return Int(match.1) }
        return idleTitles.contains(title.trimmingCharacters(in: .whitespaces)) ? 0 : nil
    }

    func update(title: String?) {
        if let parsed = Self.unreadCount(fromTitle: title) {
            titleCount = parsed
        } else if let title, !title.isEmpty, !title.hasSuffix("| Messenger") {
            // "Jane | Messenger" is just the open chat; anything else without a count is an attention title.
            lastAttention = .now
            scheduleExpiry()
        }
        refresh()
    }

    private var isAttentionActive: Bool {
        lastAttention.map { ContinuousClock.now - $0 < Self.attentionTimeout } ?? false
    }

    private func scheduleExpiry() {
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: Self.attentionTimeout)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    private func refresh() {
        let newCount = isAttentionActive ? max(titleCount, 1) : titleCount
        guard newCount != count else { return }
        let increased = newCount > count
        count = newCount
        NSApp.dockTile.badgeLabel = newCount > 0 ? String(newCount) : nil
        Log.notifications.info("unread count: \(newCount)")
        if increased { onIncrease?(newCount) }
    }
}
