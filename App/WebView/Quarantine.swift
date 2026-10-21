import CoreServices
import Foundation

/// Marks downloaded files the way browsers do, so Gatekeeper checks them before they are first opened.
/// Without it, an app sent in a chat could be launched without any warning.
enum Quarantine {
    /// Adds quarantine information unless the file already has some.
    /// - Returns: `true` if the file was already quarantined (e.g. by WebKit).
    @discardableResult
    static func mark(_ file: URL, downloadedFrom source: URL?) throws -> Bool {
        if let existing = try file.resourceValues(forKeys: [.quarantinePropertiesKey]).quarantineProperties, !existing.isEmpty {
            return true
        }
        var properties: [String: Any] = [
            kLSQuarantineAgentNameKey as String: "Messenger",
            kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload as String,
        ]
        if let source { properties[kLSQuarantineDataURLKey as String] = source }

        var values = URLResourceValues()
        values.quarantineProperties = properties
        var file = file
        try file.setResourceValues(values)
        return false
    }
}
