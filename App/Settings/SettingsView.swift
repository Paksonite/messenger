import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let updater: Updater

    @AppStorage(Preferences.showMessagePreviewKey) private var showMessagePreview = true
    @AppStorage(Preferences.showDockBadgeKey) private var showDockBadge = true
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var checksForUpdates = true
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, enabled in setOpenAtLogin(enabled) }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Notifications") {
                Toggle("Show message preview", isOn: $showMessagePreview)
                Toggle("Show unread count on the Dock icon", isOn: $showDockBadge)
                Button("Open Notification Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(Bundle.main.bundleIdentifier ?? "")") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $checksForUpdates)
                    .onChange(of: checksForUpdates) { _, enabled in updater.automaticallyChecksForUpdates = enabled }
                HStack {
                    Text(versionText)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check Now") { updater.checkForUpdates(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
        .onAppear { checksForUpdates = updater.automaticallyChecksForUpdates }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return String(localized: "Version \(version) (\(build))")
    }

    private func setOpenAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = SMAppService.mainApp.status == .requiresApproval
                ? String(localized: "Allow Messenger in System Settings → General → Login Items.")
                : nil
        } catch {
            Log.app.error("login item change failed: \(error.localizedDescription, privacy: .public)")
            loginItemError = String(localized: "Could not change the login item: \(error.localizedDescription)")
            openAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
