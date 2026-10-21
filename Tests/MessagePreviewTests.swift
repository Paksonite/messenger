import Testing
@testable import Messenger

struct MessagePreviewTests {
    @Test func parsesSeparateTimeLine() {
        let preview = MessagePreview(lines: ["Jane Doe", "See you tomorrow", "·", "2 min"])
        #expect(preview == MessagePreview(sender: "Jane Doe", text: "See you tomorrow"))
    }

    @Test func stripsInlineTime() {
        let preview = MessagePreview(lines: ["Myszka ❤️🐣🐭", "Hej, co tam? · 1 min"])
        #expect(preview == MessagePreview(sender: "Myszka ❤️🐣🐭", text: "Hej, co tam?"))
    }

    @Test func dropsScreenReaderLabels() {
        let preview = MessagePreview(lines: ["Jane", "Unread message:", "Ping", "·", "now"])
        #expect(preview == MessagePreview(sender: "Jane", text: "Ping"))
    }

    @Test func parsesRealRowWithPresenceAndUnreadLabel() {
        let preview = MessagePreview(lines: ["Aktywny teraz", "Myszka ❤️🐣🐭 Nieprzeczytana wiadomość:", "To ide", "·", "1 min"])
        #expect(preview == MessagePreview(sender: "Myszka ❤️🐣🐭", text: "To ide"))
    }

    @Test func keepsTextThatLooksLikeTimeWhenItIsTheOnlyLine() {
        #expect(MessagePreview(lines: ["Jane", "5 min"])?.text == "5 min")
    }

    @Test(arguments: [["Jane", "You: ok", "·", "1 min"], ["Jane", "Ty: ok · 1 min"]])
    func skipsOwnMessages(lines: [String]) {
        #expect(MessagePreview(lines: lines) == nil)
    }

    @Test func rejectsEmptyRow() {
        #expect(MessagePreview(lines: ["", " "]) == nil)
    }
}

extension MessagePreview {
    init(sender: String, text: String) {
        self = MessagePreview(lines: [sender, text])!
    }
}
