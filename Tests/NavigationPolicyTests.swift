import Foundation
import Testing
@testable import Messenger

struct NavigationPolicyTests {
    private func decide(_ string: String, isMainFrame: Bool = true) -> NavigationPolicy.Decision {
        NavigationPolicy.decide(URL(string: string)!, isMainFrame: isMainFrame)
    }

    @Test(arguments: [
        "https://www.messenger.com/t/123",
        "https://www.facebook.com/login/",
        "https://m.facebook.com/checkpoint/",
        "https://scontent.xx.fbcdn.net/v/image.jpg",
        "about:blank",
        "blob:https://www.messenger.com/abc",
    ])
    func staysInApp(_ url: String) {
        #expect(decide(url) == .allow)
    }

    @Test(arguments: [
        "https://example.com/",
        "https://evilmessenger.com/",
        "https://messenger.com.evil.io/",
        "mailto:someone@example.com",
    ])
    func opensExternally(_ url: String) {
        #expect(decide(url) == .openExternally(URL(string: url)!))
    }

    @Test func unwrapsFacebookRedirect() {
        let wrapped = "https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com%2Fpage%3Fa%3D1&h=AT0"
        #expect(decide(wrapped) == .openExternally(URL(string: "https://example.com/page?a=1")!))
    }

    @Test func ignoresNonHTTPRedirectTargets() {
        #expect(NavigationPolicy.unwrapRedirect(URL(string: "https://l.facebook.com/l.php?u=javascript%3Aalert(1)")!) == nil)
    }

    @Test func allowsThirdPartySubframes() {
        #expect(decide("https://www.google.com/recaptcha/", isMainFrame: false) == .allow)
    }
}

struct BadgeControllerTests {
    @Test(arguments: [
        ("(3) Messenger", 3),
        ("(12) Facebook", 12),
        ("(99+) Messenger", 99),
        ("Messenger", 0),
        ("Messenger (3)", 0),
    ])
    func parsesUnreadCount(title: String, expected: Int) {
        #expect(BadgeController.unreadCount(fromTitle: title) == expected)
    }

    @Test func handlesMissingTitle() {
        #expect(BadgeController.unreadCount(fromTitle: nil) == 0)
    }
}
