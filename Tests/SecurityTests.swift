import Foundation
import Testing
@testable import Messenger

struct NavigationBlockingTests {
    @Test(arguments: ["data:text/html,<form>login</form>", "about:config", "about:preferences"])
    func blocksTopLevelPages(_ url: String) {
        #expect(NavigationPolicy.decide(URL(string: url)!, isMainFrame: true) == .block)
    }

    @Test(arguments: ["data:image/png;base64,AAAA", "about:srcdoc", "about:config"])
    func allowsThemInSubframes(_ url: String) {
        #expect(NavigationPolicy.decide(URL(string: url)!, isMainFrame: false) == .allow)
    }

    @Test(arguments: ["about:blank", "blob:https://www.messenger.com/1234"])
    func allowsBlankPopupsAndBlobs(_ url: String) {
        #expect(NavigationPolicy.decide(URL(string: url)!, isMainFrame: true) == .allow)
    }
}

struct BridgeOriginTests {
    @Test(arguments: ["www.messenger.com", "www.facebook.com", "MESSENGER.COM"])
    func acceptsMessengerMainFrame(_ host: String) {
        #expect(NotificationBridge.acceptsMessage(isMainFrame: true, originHost: host))
    }

    @Test func rejectsSubframes() {
        #expect(!NotificationBridge.acceptsMessage(isMainFrame: false, originHost: "www.messenger.com"))
    }

    @Test(arguments: ["evil.example", "messenger.com.evil.example", "", "www.fbsbx.com.attacker.net"])
    func rejectsOtherOrigins(_ host: String) {
        #expect(!NotificationBridge.acceptsMessage(isMainFrame: true, originHost: host))
    }

    @Test(arguments: [
        "https://scontent.xx.fbcdn.net/v/t1/avatar.jpg",
        "https://static.xx.fbcdn.net/rsrc.php/icon.png",
    ])
    func allowsMessengerIcons(_ url: String) {
        #expect(NotificationBridge.iconURL(url) == URL(string: url))
    }

    @Test(arguments: [
        "http://scontent.xx.fbcdn.net/avatar.jpg",
        "https://127.0.0.1:8080/admin",
        "http://192.168.1.1/",
        "https://example.com/a.png",
        "file:///etc/passwd",
        "",
    ])
    func rejectsOtherIcons(_ url: String) {
        #expect(NotificationBridge.iconURL(url) == nil)
    }

    @Test func rejectsNonStringIcons() {
        #expect(NotificationBridge.iconURL(42) == nil)
        #expect(NotificationBridge.iconURL(nil) == nil)
    }
}

struct QuarantineTests {
    private func temporaryFile() throws -> URL {
        let file = FileManager.default.temporaryDirectory.appending(path: "quarantine-test-\(UUID().uuidString).zip")
        try Data("test".utf8).write(to: file)
        return file
    }

    private func hasQuarantineAttribute(_ file: URL) -> Bool {
        getxattr(file.path, "com.apple.quarantine", nil, 0, 0, 0) > 0
    }

    @Test func marksUnquarantinedFile() throws {
        let file = try temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(!hasQuarantineAttribute(file))

        let wasQuarantined = try Quarantine.mark(file, downloadedFrom: URL(string: "https://scontent.xx.fbcdn.net/file.zip"))

        #expect(!wasQuarantined)
        #expect(hasQuarantineAttribute(file))
    }

    @Test func keepsExistingQuarantine() throws {
        let file = try temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        try Quarantine.mark(file, downloadedFrom: nil)

        #expect(try Quarantine.mark(file, downloadedFrom: nil))
    }
}
