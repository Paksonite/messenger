import OSLog

/// Unified logging. Stream with:
/// `log stream --level debug --predicate 'subsystem == "pl.paksonite.messenger"'`
enum Log {
    static let subsystem = "pl.paksonite.messenger"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let web = Logger(subsystem: subsystem, category: "web")
    static let bridge = Logger(subsystem: subsystem, category: "bridge")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")

    /// Enables page diagnostics and logs page titles in clear text:
    /// `defaults write pl.paksonite.messenger VerboseLogging -bool true`
    static var isVerbose: Bool {
        UserDefaults.standard.bool(forKey: "VerboseLogging")
    }
}
