import Foundation
import Testing
@testable import Messenger

struct PageMessageTests {
    @Test func parsesIncomingMessage() {
        let message = PageMessage([
            "type": "message", "id": "n-1", "threadId": "742", "sender": "Jane", "text": "Hi",
            "icon": "https://scontent.xx.fbcdn.net/a.jpg",
        ])
        #expect(message == .incomingMessage(id: "n-1", threadID: "742", sender: "Jane", text: "Hi", icon: URL(string: "https://scontent.xx.fbcdn.net/a.jpg")))
    }

    @Test func dropsIconsFromOtherHosts() {
        let message = PageMessage(["type": "message", "id": "n-1", "sender": "Jane", "icon": "https://example.com/a.jpg"])
        #expect(message == .incomingMessage(id: "n-1", threadID: "", sender: "Jane", text: "", icon: nil))
    }

    @Test func parsesWebNotification() {
        let message = PageMessage(["type": "notification", "id": "n-2", "source": "service-worker", "title": "T", "body": "B", "silent": true])
        #expect(message == .webNotification(.init(id: "n-2", source: .serviceWorker, title: "T", body: "B", tag: "", icon: nil, silent: true)))
    }

    @Test func parsesCloseAndLog() {
        #expect(PageMessage(["type": "notification-close", "id": "n-3"]) == .notificationClosed(id: "n-3"))
        #expect(PageMessage(["type": "log", "message": "hello"]) == .log("hello"))
    }

    @Test(arguments: [
        ["type": "message", "id": "n-1"],
        ["type": "message", "sender": "Jane"],
        ["type": "notification"],
        ["type": "unknown", "id": "n-1"],
        ["id": "n-1"],
    ] as [[String: String]])
    func rejectsIncompleteMessages(_ body: [String: String]) {
        #expect(PageMessage(body) == nil)
    }

    @Test func rejectsNonDictionaries() {
        #expect(PageMessage("message") == nil)
    }
}

struct PageScriptTests {
    @Test func joinsAllScriptsInOrder() throws {
        let script = try #require(WebViewConfigurationFactory.pageScript(in: .main))
        var position = script.startIndex
        for name in WebViewConfigurationFactory.pageScriptNames {
            let marker = try #require(script.range(of: "// \(name).js\n", range: position..<script.endIndex), "\(name).js missing or out of order")
            position = marker.upperBound
        }
        #expect(script.hasPrefix("(() => {"))
        #expect(script.hasSuffix("})();"))
    }
}
