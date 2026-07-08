import AppKit
import Foundation

struct AppUpdateInfo {
    let version: String
    let releaseURL: URL
    let dmgURL: URL
}

final class AppUpdateManager {
    static let shared = AppUpdateManager()

    private let latestReleaseURL = URL(string: "https://api.github.com/repos/nucrasenaa/LaunchNow/releases/latest")!

    private init() {}

    func checkForUpdate() async throws -> AppUpdateInfo? {
        let (data, response) = try await URLSession.shared.data(from: latestReleaseURL)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard isVersion(latestVersion, newerThan: currentVersion) else { return nil }
        guard let asset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }),
              let dmgURL = URL(string: asset.browserDownloadURL),
              let releaseURL = URL(string: release.htmlURL) else {
            throw URLError(.fileDoesNotExist)
        }
        return AppUpdateInfo(version: latestVersion, releaseURL: releaseURL, dmgURL: dmgURL)
    }

    func downloadAndOpen(_ update: AppUpdateInfo) async throws -> URL {
        let (temporaryURL, response) = try await URLSession.shared.download(from: update.dmgURL)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let downloadsDirectory = try FileManager.default.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let destinationURL = downloadsDirectory.appendingPathComponent("LaunchNow-\(update.version).dmg")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        await MainActor.run {
            NSWorkspace.shared.open(destinationURL)
        }
        return destinationURL
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

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
