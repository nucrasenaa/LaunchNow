import AppKit
import Foundation

@MainActor
enum DiagnosticsReportBuilder {
    static func makeReport(appStore: AppStore, updateManager: AppUpdateManager) -> String {
        let now = Date()
        let supportURL = applicationSupportURL()
        let preferencesDomain = Bundle.main.bundleIdentifier ?? "unknown"
        let updaterLogURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/LaunchNowUpdater.log")

        var sections: [String] = []
        sections.append("LaunchNow Debug Info")
        sections.append("Generated: \(dateTimeFormatter.string(from: now))")
        sections.append("")

        let appLines: [String] = [
            field("Name", Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String),
            field("Version", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String),
            field("Build", Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String),
            field("Bundle ID", Bundle.main.bundleIdentifier),
            field("Bundle Path", Bundle.main.bundlePath),
            field("Executable", Bundle.main.executablePath),
            field("Dock/Agent Mode", (Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool) == true ? "LSUIElement enabled" : "Regular app")
        ]
        sections.append(section("App", appLines))

        let systemLines: [String] = [
            field("macOS", ProcessInfo.processInfo.operatingSystemVersionString),
            field("Host", Host.current().localizedName),
            field("User", NSUserName()),
            field("Locale", Locale.current.identifier),
            field("Time Zone", TimeZone.current.identifier),
            field("Processor Count", "\(ProcessInfo.processInfo.processorCount)"),
            field("Physical Memory", ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory))
        ]
        sections.append(section("System", systemLines))

        let layoutLines: [String] = [
            field("Fullscreen Mode", yesNo(appStore.isFullscreenMode)),
            field("Layout Editing", yesNo(appStore.isLayoutEditing)),
            field("Grid", "\(appStore.gridColumns)x\(appStore.gridRows)"),
            field("Items Per Page", "\(appStore.itemsPerPage)"),
            field("Current Page", "\(appStore.currentPage)"),
            field("Top Items", "\(appStore.items.count)"),
            field("Apps", "\(appStore.apps.count)"),
            field("Folders", "\(appStore.folders.count)"),
            field("Available Apps", "\(appStore.availableApps.count)"),
            field("Search Scope", appStore.searchScope.rawValue),
            field("Open Folder", appStore.openFolder?.name),
            field("Drag Creating Folder", yesNo(appStore.isDragCreatingFolder)),
            field("Folder Target", appStore.folderCreationTarget?.name)
        ]
        sections.append(section("Window & Layout", layoutLines))

        let appearanceLines: [String] = [
            field("Appearance Preset", appStore.appearancePreset.rawValue),
            field("Background Preset", appStore.backgroundPreset.rawValue),
            field("Background Opacity", String(format: "%.2f", appStore.backgroundOpacity)),
            field("Background Blur", String(format: "%.1f", appStore.backgroundBlur)),
            field("Custom Background", appStore.customBackgroundImagePath ?? "None"),
            field("Scroll Sensitivity", String(format: "%.2f", appStore.scrollSensitivity))
        ]
        sections.append(section("Appearance", appearanceLines))

        let dataStoreURL = supportURL.appendingPathComponent("Data.store")
        let dataLines: [String] = [
            field("Application Support", supportURL.path),
            field("Application Support Exists", yesNo(FileManager.default.fileExists(atPath: supportURL.path))),
            field("Data Store Exists", yesNo(FileManager.default.fileExists(atPath: dataStoreURL.path))),
            field("Profiles", "\(appStore.profiles.count)"),
            field("Profile History", "\(appStore.profileHistory.count)"),
            field("Preferences Domain", preferencesDomain)
        ]
        sections.append(section("Data", dataLines))

        let cloudLines: [String] = [
            field("Folder", appStore.cloudBackupFolderPath ?? "None"),
            field("Auto Backup", yesNo(appStore.isCloudAutoBackupEnabled)),
            field("Last Backup", appStore.lastCloudBackupAt.map(dateTimeFormatter.string(from:)) ?? "Never"),
            field("Conflict Date", appStore.cloudBackupConflictDate.map(dateTimeFormatter.string(from:)) ?? "None")
        ]
        sections.append(section("Cloud Backup", cloudLines))

        let updateLines: [String] = [
            field("Auto Check", yesNo(updateManager.isAutomaticCheckEnabled)),
            field("Auto Install", yesNo(updateManager.isAutomaticInstallEnabled)),
            field("Last Auto Check", updateManager.lastAutomaticCheckAt.map(dateTimeFormatter.string(from:)) ?? "Never"),
            field("Last Auto Check Failed", yesNo(updateManager.lastAutomaticCheckFailed)),
            field("Available Update", updateManager.automaticallyAvailableUpdate?.version ?? "None"),
            field("Last Update Error", updateManager.lastUpdateErrorMessage ?? "None"),
            field("Updater Log Path", updaterLogURL.path),
            field("Updater Log Exists", yesNo(FileManager.default.fileExists(atPath: updaterLogURL.path)))
        ]
        sections.append(section("Update", updateLines))

        var sourceLines = appStore.systemApplicationSearchPaths.map { field("System", $0) }
        sourceLines.append(contentsOf: appStore.customApplicationSearchPaths.map { field("Custom", $0) })
        sections.append(section("Application Sources", sourceLines))
        sections.append(section("Recent Update Logs", updateLogLines(updateManager.updateLogs)))
        sections.append(section("Recent Updater File Log", tailLines(from: updaterLogURL, maxLines: 80)))

        return sections.joined(separator: "\n")
    }

    static func suggestedFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "LaunchNow_Debug_\(formatter.string(from: Date())).txt"
    }

    static func applicationSupportURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("LaunchNow", isDirectory: true)
    }

    private static var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }

    private static func section(_ title: String, _ lines: [String]) -> String {
        let body = lines.isEmpty ? ["None"] : lines
        return (["## \(title)"] + body).joined(separator: "\n")
    }

    private static func field(_ name: String, _ value: String?) -> String {
        "\(name): \(value?.isEmpty == false ? value! : "Unknown")"
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private static func updateLogLines(_ logs: [AppUpdateLogEntry]) -> [String] {
        guard !logs.isEmpty else { return [] }
        return logs.map { entry in
            let level = entry.isError ? "ERROR" : "INFO"
            return "[\(level)] \(dateTimeFormatter.string(from: entry.date)) - \(entry.title): \(entry.detail)"
        }
    }

    private static func tailLines(from url: URL, maxLines: Int) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.suffix(maxLines).map(String.init)
    }
}
