import Foundation
import WebKit

enum WebViewConfigurationFactory {
    @MainActor
    static func make(bridge: NotificationBridge) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        // Persistent store keeps the login session and end-to-end encryption keys across launches.
        configuration.websiteDataStore = .default()
        configuration.applicationNameForUserAgent = "Version/\(safariVersion) Safari/605.1.15"
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()
        if let source = script(named: "notification-shim") {
            contentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
        } else {
            Log.web.error("notification-shim.js missing from bundle")
        }
        contentController.add(bridge, name: NotificationBridge.messageHandlerName)
        configuration.userContentController = contentController

        return configuration
    }

    /// Matches the installed Safari so Meta serves the same code it serves to Safari.
    static var safariVersion: String {
        let safari = URL(fileURLWithPath: "/Applications/Safari.app")
        return Bundle(url: safari)?.infoDictionary?["CFBundleShortVersionString"] as? String ?? "18.0"
    }

    private static func script(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
