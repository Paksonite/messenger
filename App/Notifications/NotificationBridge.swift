import AppKit
import UserNotifications
import WebKit

/// Receives web notifications from `notification-shim.js` and shows them as native macOS notifications.
@MainActor
final class NotificationBridge: NSObject {
    static let messageHandlerName = "messengerBridge"

    weak var webView: WKWebView?
    var onActivate: (() -> Void)?

    private let center = UNUserNotificationCenter.current()

    /// How long to wait for a web notification after the unread count goes up before posting a fallback.
    private static let fallbackDelay: Duration = .seconds(2)
    private var lastWebNotification = Date.distantPast
    /// Latest title Messenger flashed while something is unread, e.g. "Jane sent a message".
    private var attentionTitle: (text: String, date: Date)?
    /// Thread and text of the last message notification, to skip duplicates.
    private var lastMessage: (key: String, date: Date)?

    private var isWindowFocused: Bool {
        NSApp.isActive && webView?.window?.isKeyWindow == true
    }

    func requestAuthorization() {
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                Log.notifications.info("authorization granted: \(granted)")
                // Completion handler form: UNNotificationSettings is not Sendable in older SDKs.
                center.getNotificationSettings { @Sendable settings in
                    Log.notifications.info(
                        "alert style: \(settings.alertStyle.rawValue), sound: \(settings.soundSetting.rawValue)"
                    )
                }
            } catch {
                Log.notifications.error("authorization failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func titleChanged(_ title: String?) {
        guard let title, !title.isEmpty, BadgeController.unreadCount(fromTitle: title) == nil else { return }
        attentionTitle = (title, Date())
    }

    /// Fallback for when the page raises the unread count without calling the Notification API.
    func unreadCountIncreased(to count: Int) {
        Task {
            try? await Task.sleep(for: Self.fallbackDelay)
            let freshness = Double(Self.fallbackDelay.components.seconds) * 2
            guard Date().timeIntervalSince(lastWebNotification) > freshness else { return }
            guard !isWindowFocused else { return }

            let recentTitle = attentionTitle.flatMap { Date().timeIntervalSince($0.date) < freshness ? $0.text : nil }
            Log.notifications.info("no web notification for unread count \(count), posting fallback")
            // Messenger plays its own sound for new messages, so the fallback stays silent.
            show(Payload(
                id: "fallback-\(UUID().uuidString)",
                source: "fallback",
                title: "Messenger",
                body: recentTitle ?? (count == 1 ? "New message" : "\(count) unread chats"),
                tag: "fallback",
                icon: nil,
                silent: true
            ))
        }
    }

    /// An incoming message detected by the shim from Messenger's message sound and the chat list.
    private func showMessage(id: String, threadID: String, lines: [String], icon: URL?) {
        if Log.isVerbose {
            Log.bridge.info("message row \(threadID, privacy: .public): \(lines, privacy: .public)")
        }
        guard !isWindowFocused else { return }
        guard let preview = MessagePreview(lines: lines) else {
            Log.notifications.info("message row skipped (own message or unreadable)")
            return
        }

        let key = "\(threadID)|\(preview.text)"
        if let lastMessage, lastMessage.key == key, Date().timeIntervalSince(lastMessage.date) < 10 { return }
        lastMessage = (key, Date())

        // Messenger already plays its own sound for the message.
        show(Payload(
            id: id,
            source: "message",
            title: preview.sender,
            body: preview.text.isEmpty ? "New message" : preview.text,
            tag: threadID,
            icon: icon,
            silent: true
        ))
    }

    /// Called when the user clicks a delivered notification.
    func activate(notificationID id: String) {
        onActivate?()
        guard let literal = Self.jsStringLiteral(id) else { return }
        webView?.evaluateJavaScript("window.__messengerBridge?.click(\(literal))") { result, error in
            if let error {
                Log.bridge.error("click dispatch failed: \(error.localizedDescription, privacy: .public)")
            } else if (result as? Bool) != true {
                Log.bridge.info("no live notification for click \(id, privacy: .public)")
            }
        }
    }

    private func show(_ payload: Payload) {
        Log.notifications.info("notification from \(payload.source, privacy: .public): \(payload.title, privacy: .private)")
        if payload.source != "fallback" { lastWebNotification = Date() }
        Task {
            let content = UNMutableNotificationContent()
            content.title = payload.title
            content.body = payload.body
            content.threadIdentifier = payload.tag.isEmpty ? payload.title : payload.tag
            content.userInfo = ["id": payload.id]
            if !payload.silent { content.sound = .default }
            if let icon = payload.icon,
               let file = await Self.downloadIcon(from: icon, id: payload.id),
               let attachment = try? UNNotificationAttachment(identifier: payload.id, url: file) {
                content.attachments = [attachment]
            }

            do {
                try await center.add(UNNotificationRequest(identifier: payload.id, content: content, trigger: nil))
            } catch {
                Log.notifications.error("delivery failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func remove(id: String) {
        center.removeDeliveredNotifications(withIdentifiers: [id])
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    nonisolated private static func downloadIcon(from url: URL, id: String) async -> URL? {
        let request = URLRequest(url: url, timeoutInterval: 3)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        let ext = response.mimeType == "image/png" ? "png" : "jpg"
        let file = FileManager.default.temporaryDirectory.appending(path: "notification-\(id).\(ext)")
        return (try? data.write(to: file)) != nil ? file : nil
    }

    private static func jsStringLiteral(_ value: String) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension NotificationBridge: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "notification":
            if let payload = Payload(body) { show(payload) }
        case "message":
            guard let id = body["id"] as? String, let lines = body["lines"] as? [String] else { return }
            showMessage(
                id: id,
                threadID: body["threadId"] as? String ?? "",
                lines: lines,
                icon: (body["icon"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
            )
        case "notification-close":
            if let id = body["id"] as? String { remove(id: id) }
        case "log":
            Log.bridge.info("js: \(body["message"] as? String ?? "", privacy: .public)")
        default:
            Log.bridge.error("unknown message type: \(type, privacy: .public)")
        }
    }
}

extension NotificationBridge {
    struct Payload {
        let id: String
        let source: String
        let title: String
        let body: String
        let tag: String
        let icon: URL?
        let silent: Bool

        init(id: String, source: String, title: String, body: String, tag: String, icon: URL?, silent: Bool) {
            self.id = id
            self.source = source
            self.title = title
            self.body = body
            self.tag = tag
            self.icon = icon
            self.silent = silent
        }

        init?(_ body: [String: Any]) {
            guard let id = body["id"] as? String, !id.isEmpty else { return nil }
            self.id = id
            source = body["source"] as? String ?? "window"
            title = body["title"] as? String ?? ""
            self.body = body["body"] as? String ?? ""
            tag = body["tag"] as? String ?? ""
            icon = (body["icon"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
            silent = body["silent"] as? Bool ?? false
        }
    }
}
