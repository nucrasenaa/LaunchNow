import AppKit
import Combine
import Darwin
import Foundation
import UserNotifications

struct AppUpdateInfo {
    let version: String
    let releaseURL: URL
    let packageURL: URL
    let packageName: String
    let packageKind: PackageKind

    enum PackageKind {
        case zip
        case dmg
    }
}

struct AppUpdateLogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let detail: String
    let isError: Bool
}

final class AppUpdateManager: ObservableObject {
    static let shared = AppUpdateManager()

    private let latestReleaseURL = URL(string: "https://api.github.com/repos/nucrasenaa/LaunchNow/releases/latest")!
    private let automaticCheckInterval: TimeInterval = 6 * 60 * 60
    private let automaticChecksEnabledKey = "automaticUpdateChecksEnabled"
    private let lastAutomaticCheckKey = "lastAutomaticUpdateCheckAt"
    private let lastNotifiedVersionKey = "lastNotifiedUpdateVersion"
    private var automaticUpdateTimer: Timer?
    private var isAutomaticUpdateRunning = false

    @Published var isAutomaticCheckEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutomaticCheckEnabled, forKey: automaticChecksEnabledKey)
            if isAutomaticCheckEnabled {
                startAutomaticUpdateChecks()
            } else {
                stopAutomaticUpdateChecks()
            }
        }
    }
    @Published private(set) var automaticallyAvailableUpdate: AppUpdateInfo?
    @Published private(set) var lastAutomaticCheckAt: Date?
    @Published private(set) var lastAutomaticCheckFailed = false
    @Published private(set) var lastUpdateErrorMessage: String?
    @Published private(set) var updateLogs: [AppUpdateLogEntry] = []

    private init() {
        if UserDefaults.standard.object(forKey: automaticChecksEnabledKey) == nil {
            isAutomaticCheckEnabled = true
        } else {
            isAutomaticCheckEnabled = UserDefaults.standard.bool(forKey: automaticChecksEnabledKey)
        }
        lastAutomaticCheckAt = UserDefaults.standard.object(forKey: lastAutomaticCheckKey) as? Date
    }

    func startAutomaticUpdateChecks() {
        automaticUpdateTimer?.invalidate()
        guard isAutomaticCheckEnabled else { return }

        Task {
            try? await Task.sleep(for: .seconds(10))
            await prepareNotificationAuthorizationIfNeeded()
            await checkAutomatically(force: true)
        }

        automaticUpdateTimer = Timer.scheduledTimer(withTimeInterval: automaticCheckInterval, repeats: true) { [weak self] _ in
            Task { await self?.checkAutomatically(force: false) }
        }
    }

    func stopAutomaticUpdateChecks() {
        automaticUpdateTimer?.invalidate()
        automaticUpdateTimer = nil
    }

    func clearAutomaticallyAvailableUpdate() {
        automaticallyAvailableUpdate = nil
    }

    @MainActor
    func recordUpdateLog(title: String, detail: String, isError: Bool = false) {
        if isError {
            lastUpdateErrorMessage = detail
        }
        updateLogs.insert(
            AppUpdateLogEntry(date: Date(), title: title, detail: detail, isError: isError),
            at: 0
        )
        if updateLogs.count > 8 {
            updateLogs.removeLast(updateLogs.count - 8)
        }
    }

    @MainActor
    func clearUpdateError() {
        lastUpdateErrorMessage = nil
    }

    func readableError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection."
            case .timedOut:
                return "The request timed out."
            case .badServerResponse:
                return "GitHub returned an unexpected response."
            case .fileDoesNotExist:
                return "No compatible update package was found in the latest release."
            case .cannotCreateFile:
                return "LaunchNow could not prepare the updater files."
            default:
                return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    func checkForUpdate() async throws -> AppUpdateInfo? {
        let (data, response) = try await URLSession.shared.data(from: latestReleaseURL)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard isVersion(latestVersion, newerThan: currentVersion) else { return nil }
        guard let asset = preferredUpdateAsset(from: release.assets),
              let packageKind = asset.packageKind,
              let packageURL = URL(string: asset.browserDownloadURL),
              let releaseURL = URL(string: release.htmlURL) else {
            throw URLError(.fileDoesNotExist)
        }
        return AppUpdateInfo(
            version: latestVersion,
            releaseURL: releaseURL,
            packageURL: packageURL,
            packageName: asset.name,
            packageKind: packageKind
        )
    }

    func downloadAndInstall(_ update: AppUpdateInfo) async throws -> URL {
        let (temporaryURL, response) = try await URLSession.shared.download(from: update.packageURL)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        switch update.packageKind {
        case .zip:
            return try await installFromZip(temporaryURL, update: update)
        case .dmg:
            return try await saveAndOpenDMG(temporaryURL, update: update)
        }
    }

    private func checkAutomatically(force: Bool) async {
        guard isAutomaticCheckEnabled else { return }
        guard !isAutomaticUpdateRunning else { return }

        let now = Date()
        let lastCheck = UserDefaults.standard.object(forKey: lastAutomaticCheckKey) as? Date ?? .distantPast
        guard force || now.timeIntervalSince(lastCheck) >= automaticCheckInterval else { return }

        isAutomaticUpdateRunning = true
        UserDefaults.standard.set(now, forKey: lastAutomaticCheckKey)
        defer { isAutomaticUpdateRunning = false }

        do {
            let update = try await checkForUpdate()
            await MainActor.run {
                self.automaticallyAvailableUpdate = update
                self.lastAutomaticCheckAt = now
                self.lastAutomaticCheckFailed = false
                self.lastUpdateErrorMessage = nil
                self.recordUpdateLog(
                    title: "Automatic check",
                    detail: update.map { "Version \($0.version) is available." } ?? "LaunchNow is up to date."
                )
            }
            if let update {
                await notifyUpdateAvailableIfNeeded(update)
            }
        } catch {
            let message = readableError(error)
            await MainActor.run {
                self.lastAutomaticCheckAt = now
                self.lastAutomaticCheckFailed = true
                self.recordUpdateLog(title: "Automatic check failed", detail: message, isError: true)
            }
        }
    }

    private func prepareNotificationAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    private func notifyUpdateAvailableIfNeeded(_ update: AppUpdateInfo) async {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: lastNotifiedVersionKey) != update.version else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = LocalizationManager.shared.text(.updateNotificationTitleFormat, update.version)
        content.body = LocalizationManager.shared.text(.updateNotificationBody)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "LaunchNowUpdate-\(update.version)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            defaults.set(update.version, forKey: lastNotifiedVersionKey)
        } catch {
            // Notifications are best-effort; Settings still shows the available update.
        }
    }

    private func installFromZip(_ zipURL: URL, update: AppUpdateInfo) async throws -> URL {
        let fileManager = FileManager.default
        let workDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("LaunchNowUpdate-\(UUID().uuidString)", isDirectory: true)
        let extractDirectory = workDirectory.appendingPathComponent("Extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractDirectory, withIntermediateDirectories: true)

        let zipDestination = workDirectory.appendingPathComponent(update.packageName)
        try fileManager.moveItem(at: zipURL, to: zipDestination)
        try runProcess("/usr/bin/ditto", arguments: ["-x", "-k", zipDestination.path, extractDirectory.path])

        let sourceAppURL = try findLaunchNowApp(in: extractDirectory)
        let destinationAppURL = Bundle.main.bundleURL
        guard destinationAppURL.pathExtension == "app" else {
            throw URLError(.cannotCreateFile)
        }

        let scriptURL = workDirectory.appendingPathComponent("install.sh")
        let script = installerScript(
            sourceAppPath: sourceAppURL.path,
            destinationAppPath: destinationAppURL.path,
            workDirectoryPath: workDirectory.path,
            processID: ProcessInfo.processInfo.processIdentifier
        )
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            "-c",
            "nohup /bin/zsh \(shellQuoted(scriptURL.path)) >/dev/null 2>&1 &"
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw URLError(.cannotCreateFile)
        }

        await MainActor.run {
            NSApp.terminate(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                exit(0)
            }
        }
        return destinationAppURL
    }

    private func saveAndOpenDMG(_ temporaryURL: URL, update: AppUpdateInfo) async throws -> URL {
        let downloadsDirectory = try FileManager.default.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let destinationURL = downloadsDirectory.appendingPathComponent(update.packageName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        await MainActor.run {
            _ = NSWorkspace.shared.open(destinationURL)
        }
        return destinationURL
    }

    private func preferredUpdateAsset(from assets: [GitHubReleaseAsset]) -> GitHubReleaseAsset? {
        assets.first(where: { $0.packageKind == .zip }) ?? assets.first(where: { $0.packageKind == .dmg })
    }

    private func findLaunchNowApp(in directory: URL) throws -> URL {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw URLError(.fileDoesNotExist)
        }

        for case let url as URL in enumerator where url.lastPathComponent == "LaunchNow.app" {
            return url
        }
        throw URLError(.fileDoesNotExist)
    }

    private func runProcess(_ launchPath: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw URLError(.cannotDecodeContentData)
        }
    }

    private func installerScript(
        sourceAppPath: String,
        destinationAppPath: String,
        workDirectoryPath: String,
        processID: Int32
    ) -> String {
        let privilegedInstallCommand = """
        /bin/rm -rf \(shellQuoted(destinationAppPath)) && /usr/bin/ditto \(shellQuoted(sourceAppPath)) \(shellQuoted(destinationAppPath)); install_status=$?; /usr/bin/xattr -dr com.apple.quarantine \(shellQuoted(destinationAppPath)) 2>/dev/null || true; exit $install_status
        """

        return """
        #!/bin/zsh
        set -u

        SOURCE_APP=\(shellQuoted(sourceAppPath))
        DESTINATION_APP=\(shellQuoted(destinationAppPath))
        WORK_DIR=\(shellQuoted(workDirectoryPath))
        OLD_PID=\(processID)
        LOG_FILE="$HOME/Library/Logs/LaunchNowUpdater.log"

        mkdir -p "$HOME/Library/Logs"
        exec >> "$LOG_FILE" 2>&1

        echo "---- LaunchNow updater started $(date) ----"
        echo "source=$SOURCE_APP"
        echo "destination=$DESTINATION_APP"
        echo "old_pid=$OLD_PID"

        for _ in {1..80}; do
          if ! kill -0 "$OLD_PID" 2>/dev/null; then
            break
          fi
          sleep 0.25
        done

        install_without_prompt() {
          /bin/rm -rf "$DESTINATION_APP" &&
          /usr/bin/ditto "$SOURCE_APP" "$DESTINATION_APP"
          local install_status=$?
          /usr/bin/xattr -dr com.apple.quarantine "$DESTINATION_APP" 2>/dev/null || true
          return $install_status
        }

        if install_without_prompt; then
          echo "installed without administrator privileges"
        else
          echo "direct install failed; requesting administrator privileges"
          /usr/bin/osascript <<'APPLESCRIPT'
        do shell script \(appleScriptStringLiteral(privilegedInstallCommand)) with administrator privileges
        APPLESCRIPT
        fi

        INSTALLED_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DESTINATION_APP/Contents/Info.plist" 2>/dev/null || true)
        echo "installed_version=$INSTALLED_VERSION"
        /usr/bin/open "$DESTINATION_APP"
        rm -rf "$WORK_DIR"
        echo "---- LaunchNow updater finished $(date) ----"
        """
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptStringLiteral(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n") + "\""
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedDescending
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    var packageKind: AppUpdateInfo.PackageKind? {
        let lowercasedName = name.lowercased()
        if lowercasedName.hasSuffix(".zip") { return .zip }
        if lowercasedName.hasSuffix(".dmg") { return .dmg }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
