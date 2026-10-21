import Foundation

/// A message from the page scripts (Resources/Scripts) to the app, posted to the `messengerBridge` handler.
enum PageMessage: Equatable {
    /// A call to the web Notification API (notification-api.js).
    case webNotification(NotificationBridge.Payload)
    /// A new message or reaction read from the chat list (incoming-messages.js).
    case incomingMessage(id: String, threadID: String, sender: String, text: String, icon: URL?)
    /// The page closed a web notification.
    case notificationClosed(id: String)
    case log(String)

    init?(_ body: Any) {
        guard let body = body as? [String: Any], let type = body["type"] as? String else { return nil }
        let id = body["id"] as? String ?? ""
        switch type {
        case "notification":
            guard !id.isEmpty else { return nil }
            self = .webNotification(NotificationBridge.Payload(
                id: id,
                source: (body["source"] as? String).flatMap(NotificationBridge.Payload.Source.init(rawValue:)) ?? .webNotification,
                title: body["title"] as? String ?? "",
                body: body["body"] as? String ?? "",
                tag: body["tag"] as? String ?? "",
                icon: NotificationBridge.iconURL(body["icon"]),
                silent: body["silent"] as? Bool ?? false
            ))
        case "message":
            guard !id.isEmpty, let sender = body["sender"] as? String, !sender.isEmpty else { return nil }
            self = .incomingMessage(
                id: id,
                threadID: body["threadId"] as? String ?? "",
                sender: sender,
                text: body["text"] as? String ?? "",
                icon: NotificationBridge.iconURL(body["icon"])
            )
        case "notification-close":
            guard !id.isEmpty else { return nil }
            self = .notificationClosed(id: id)
        case "log":
            self = .log(body["message"] as? String ?? "")
        default:
            return nil
        }
    }
}
