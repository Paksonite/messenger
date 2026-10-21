import Foundation

/// User preferences stored in UserDefaults; the keys double as `@AppStorage` keys in the settings window.
enum Preferences {
    static let showMessagePreviewKey = "ShowMessagePreview"
    static let showDockBadgeKey = "ShowDockBadge"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMessagePreviewKey: true,
            showDockBadgeKey: true,
        ])
    }

    /// Show the message text in notifications; when off, only the sender is shown.
    static var showMessagePreview: Bool {
        UserDefaults.standard.bool(forKey: showMessagePreviewKey)
    }

    static var showDockBadge: Bool {
        UserDefaults.standard.bool(forKey: showDockBadgeKey)
    }
}
