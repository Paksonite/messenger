import Foundation

/// Decides which URLs stay inside the app and which go to the default browser.
enum NavigationPolicy {
    enum Decision: Equatable {
        case allow
        case openExternally(URL)
        /// Not loaded anywhere, e.g. a top-level `data:` page, which could pose as a login form.
        case block
    }

    static let startURL = URL(string: "https://www.messenger.com/")!

    /// Domains needed for Messenger itself, Facebook login/checkpoints and media.
    static let internalDomains = [
        "messenger.com",
        "facebook.com",
        "facebook.net",
        "fbcdn.net",
        "fbsbx.com",
    ]

    static func decide(_ url: URL, isMainFrame: Bool) -> Decision {
        switch url.scheme?.lowercased() {
        case nil, "blob":
            return .allow
        case "about":
            // Popups start at about:blank; other about: pages have no use at the top level.
            return !isMainFrame || ["about:blank", "about:srcdoc"].contains(url.absoluteString) ? .allow : .block
        case "data":
            // Browsers refuse top-level data: navigations for the same reason.
            return isMainFrame ? .block : .allow
        case "http", "https":
            break
        default:
            return .openExternally(url)
        }
        if let target = unwrapRedirect(url) {
            return .openExternally(target)
        }
        if isInternal(url) || !isMainFrame {
            return .allow
        }
        return .openExternally(url)
    }

    /// Conversation pages: /t/<id> and end-to-end encrypted /e2ee/t/<id>.
    static func isConversation(_ url: URL) -> Bool {
        isInternal(url) && (url.path.hasPrefix("/t/") || url.path.hasPrefix("/e2ee/t/"))
    }

    /// The page to open at launch: the last conversation if it is still a valid Messenger URL.
    static func launchURL(lastConversation: String?) -> URL {
        guard let lastConversation, let url = URL(string: lastConversation), isConversation(url) else { return startURL }
        return url
    }

    static func isInternal(_ url: URL) -> Bool {
        url.host.map(isInternal(host:)) ?? false
    }

    static func isInternal(host: String) -> Bool {
        let host = host.lowercased()
        return internalDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// Notification icons are fetched natively, so only Messenger's own HTTPS image hosts are allowed.
    static func isAllowedIconURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && isInternal(url)
    }

    /// Facebook wraps outgoing links as `l.facebook.com/l.php?u=<target>`.
    static func unwrapRedirect(_ url: URL) -> URL? {
        guard let host = url.host?.lowercased(),
              host.hasPrefix("l.") || host.hasPrefix("lm."),
              isInternal(url),
              url.path == "/l.php",
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "u" })?.value,
              let target = URL(string: value),
              ["http", "https"].contains(target.scheme?.lowercased() ?? "")
        else { return nil }
        return target
    }
}
