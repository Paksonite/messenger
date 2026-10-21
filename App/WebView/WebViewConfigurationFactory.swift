import Foundation
import WebKit

enum WebViewConfigurationFactory {
    /// Page scripts in Resources/Scripts, in the order they run. They are joined into one function so
    /// they share helpers from core.js without exposing them to the page.
    static let pageScriptNames = [
        "core",
        "text-rules",
        "workarounds",
        "notification-api",
        "chat-list",
        "incoming-messages",
        "shortcuts",
        "diagnostics",
        "bridge",
    ]

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
        if Log.isVerbose {
            contentController.addUserScript(
                WKUserScript(source: "window.__messengerDiagnostics = true;", injectionTime: .atDocumentStart, forMainFrameOnly: false)
            )
        }
        if let source = pageScript(in: .main) {
            contentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            )
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

    /// All page scripts joined into one strict-mode function that runs once per frame.
    static func pageScript(in bundle: Bundle) -> String? {
        var parts: [String] = []
        for name in pageScriptNames {
            guard let url = bundle.url(forResource: name, withExtension: "js"),
                  let source = try? String(contentsOf: url, encoding: .utf8)
            else {
                Log.web.error("page script \(name, privacy: .public).js missing from bundle")
                return nil
            }
            parts.append("// \(name).js\n\(source)")
        }
        return """
        (() => {
        "use strict";
        if (window.__messengerBridge) return;
        \(parts.joined(separator: "\n"))
        })();
        """
    }
}
