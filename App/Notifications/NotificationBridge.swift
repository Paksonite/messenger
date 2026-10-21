import AppKit
import UserNotifications
import WebKit

/// Receives messages from the page scripts and shows them as native macOS notifications.
@MainActor
final class NotificationBridge: NSObject {
    static let messageHandlerName = "messengerBridge"

    private enum Timing {
        /// After the unread count goes up, how long to wait for a message notification before posting a fallback.
        static let fallbackDelay: Duration = .seconds(2)
        /// A message or attention title within this window counts as covering an unread count increase.
        static let freshness: TimeInterval = 4
        /// The same text in the same chat within this window is a duplicate.
        static let duplicateWindow: TimeInterval = 10
        static let iconTimeout: TimeInterval = 3
    }

    weak var webView: WKWebView?
    var onActivate: (() -> Void)?

    private let center = UNUserNotificationCenter.current()
    private var lastPageNotification = Date.distantPast
    /// Latest title Messenger flashed while something is unread, e.g. "Jane sent a message".
    private var attentionTitle: (text: String, date: Date)?
    /// Thread and text of the last message notification, to skip duplicates.
    private var lastMessage: (key: String, date: Date)?

    private var isWindowFocused: Bool {
        NSApp.isActive && webView?.window?.isKeyWindow == true
    }

    // UNUserNotificationCenter calls use completion handlers from synchronous methods: in older SDKs the
    // center and its settings are not Sendable, so their async variants don't compile from the main actor.
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { @Sendable granted, error in
            if let error {
                Log.notifications.error("authorization failed: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.notifications.info("authorization granted: \(granted)")
            }
        }
        center.getNotificationSettings { @Sendable settings in
            Log.notifications.info(
                "alert style: \(settings.alertStyle.rawValue), sound: \(settings.soundSetting.rawValue)"
            )
        }
    }

    func titleChanged(_ title: String?) {
        guard let title, !title.isEmpty, BadgeController.unreadCount(fromTitle: title) == nil else { return }
        attentionTitle = (title, Date())
    }

    /// Fallback for when the unread count goes up but the page scripts reported no message.
    func unreadCountIncreased(to count: Int) {
        Task {
            try? await Task.sleep(for: Timing.fallbackDelay)
            guard Date().timeIntervalSince(lastPageNotification) > Timing.freshness, !isWindowFocused else { return }

            let recentTitle = attentionTitle.flatMap { Date().timeIntervalSince($0.date) < Timing.freshness ? $0.text : nil }
            Log.notifications.info("no message reported for unread count \(count), posting fallback")
            // Messenger plays its own sound for new messages, so the fallback stays silent.
            show(Payload(
                id: "fallback-\(UUID().uuidString)",
                source: .fallback,
                title: "Messenger",
                body: recentTitle ?? (count == 1 ? String(localized: "New message") : String(localized: "\(count) unread chats")),
                tag: "fallback",
                icon: nil,
                silent: true
            ))
        }
    }

    private func showMessage(id: String, threadID: String, sender: String, text: String, icon: URL?) {
        guard !isWindowFocused else { return }

        let key = "\(threadID)|\(text)"
        if let lastMessage, lastMessage.key == key, Date().timeIntervalSince(lastMessage.date) < Timing.duplicateWindow { return }
        lastMessage = (key, Date())

        // Messenger already plays its own sound for the message.
        show(Payload(
            id: id,
            source: .message,
            title: sender,
            body: Preferences.showMessagePreview && !text.isEmpty ? text : String(localized: "New message"),
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
        Log.notifications.info("notification from \(payload.source.rawValue, privacy: .public): \(payload.title, privacy: .private)")
        if payload.source != .fallback { lastPageNotification = Date() }
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
            deliver(UNNotificationRequest(identifier: payload.id, content: content, trigger: nil))
        }
    }

    private func deliver(_ request: UNNotificationRequest) {
        center.add(request) { @Sendable error in
            if let error {
                Log.notifications.error("delivery failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func remove(id: String) {
        center.removeDeliveredNotifications(withIdentifiers: [id])
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    nonisolated private static func downloadIcon(from url: URL, id: String) async -> URL? {
        let request = URLRequest(url: url, timeoutInterval: Timing.iconTimeout)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        let ext = response.mimeType == "image/png" ? "png" : "jpg"
        let file = FileManager.default.temporaryDirectory.appending(path: "notification-\(id).\(ext)")
        return (try? data.write(to: file)) != nil ? file : nil
    }

    /// Icons are fetched natively, so only Messenger's own HTTPS image hosts are accepted.
    nonisolated static func iconURL(_ value: Any?) -> URL? {
        guard let string = value as? String, let url = URL(string: string), NavigationPolicy.isAllowedIconURL(url) else { return nil }
        return url
    }

    private static func jsStringLiteral(_ value: String) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension NotificationBridge: WKScriptMessageHandler {
    /// The handler is reachable from every frame, including embedded third-party ones, which could
    /// otherwise post fake notifications or make the app fetch arbitrary URLs as icons.
    nonisolated static func acceptsMessage(isMainFrame: Bool, originHost: String) -> Bool {
        isMainFrame && NavigationPolicy.isInternal(host: originHost)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard Self.acceptsMessage(isMainFrame: message.frameInfo.isMainFrame, originHost: message.frameInfo.securityOrigin.host) else {
            Log.bridge.error("ignored bridge message from \(message.frameInfo.securityOrigin.host, privacy: .private)")
            return
        }
        switch PageMessage(message.body) {
        case .webNotification(let payload):
            show(payload)
        case let .incomingMessage(id, threadID, sender, text, icon):
            showMessage(id: id, threadID: threadID, sender: sender, text: text, icon: icon)
        case .notificationClosed(let id):
            remove(id: id)
        case .log(let text):
            Log.bridge.info("js: \(text, privacy: .public)")
        case nil:
            Log.bridge.error("unreadable bridge message")
        }
    }
}

extension NotificationBridge {
    struct Payload: Equatable {
        enum Source: String {
            case webNotification = "window"
            case serviceWorker = "service-worker"
            case message
            case fallback
        }

        let id: String
        let source: Source
        let title: String
        let body: String
        let tag: String
        let icon: URL?
        let silent: Bool
    }
}
