import Foundation

/// Sender and text of the newest message, parsed from the text lines of a chat list row,
/// e.g. `["Jane Doe", "See you tomorrow", "·", "2 min"]`.
struct MessagePreview: Equatable {
    let sender: String
    let text: String

    /// Screen reader labels Messenger puts inside rows; dropped before parsing.
    private static let noise: Set<String> = [
        "·", "Unread message:", "Nieprzeczytana wiadomość:", "Active now", "Aktywny(-a) teraz",
    ]

    /// Prefixes of the user's own messages, which should not notify.
    private static let ownPrefixes = ["You: ", "You sent", "Ty: ", "Wysłano"]

    init?(lines: [String]) {
        let lines = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !Self.noise.contains($0) }
        guard let sender = lines.first else { return nil }

        var rest = Array(lines.dropFirst())
        // The last line is the relative time ("2 min", "1h", "teraz") when it is short and has no spaces in the text part.
        if rest.count > 1, let last = rest.last, Self.looksLikeTime(last) { rest.removeLast() }
        let text = rest.joined(separator: " ")
            .replacing(/\s+·\s+[^·]{1,12}$/, with: "")
            .trimmingCharacters(in: .whitespaces)

        if Self.ownPrefixes.contains(where: text.hasPrefix) { return nil }
        self.sender = sender
        self.text = text
    }

    private static func looksLikeTime(_ value: String) -> Bool {
        value.count <= 12 && value.firstMatch(of: /^(\d+\s?\p{L}{1,6}\.?|now|teraz|just now)$/) != nil
    }
}
