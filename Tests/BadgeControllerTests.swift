import Testing
@testable import Messenger

struct BadgeControllerTests {
    @Test(arguments: [
        ("(3) Messenger", 3),
        ("(12) Facebook", 12),
        ("(99+) Messenger", 99),
        ("Messenger", 0),
        ("Facebook", 0),
    ])
    func parsesUnreadCount(title: String, expected: Int) {
        #expect(BadgeController.unreadCount(fromTitle: title) == expected)
    }

    @Test(arguments: ["Jane Doe sent a message", "Messenger (3)", ""])
    func ignoresTitlesWithoutCount(title: String) {
        #expect(BadgeController.unreadCount(fromTitle: title) == nil)
    }

    @Test func handlesMissingTitle() {
        #expect(BadgeController.unreadCount(fromTitle: nil) == nil)
    }
}
