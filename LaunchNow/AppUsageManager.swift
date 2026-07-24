import Foundation

struct AppUsageRecord: Codable, Equatable {
    var appPath: String
    var launchCount: Int
    var lastLaunchedAt: Date
}

final class AppUsageManager {
    static let shared = AppUsageManager()

    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var recordsByPath: [String: AppUsageRecord]

    private init() {
        recordsByPath = (try? Self.loadRecords(from: Self.storageURL(fileManager: fileManager))) ?? [:]
    }

    func recordLaunch(for app: AppInfo) {
        lock.lock()
        var record = recordsByPath[app.url.path] ?? AppUsageRecord(
            appPath: app.url.path,
            launchCount: 0,
            lastLaunchedAt: .distantPast
        )
        record.launchCount += 1
        record.lastLaunchedAt = Date()
        recordsByPath[app.url.path] = record
        let snapshot = recordsByPath
        lock.unlock()

        persist(snapshot)
    }

    func record(for appPath: String) -> AppUsageRecord? {
        lock.lock()
        defer { lock.unlock() }
        return recordsByPath[appPath]
    }

    func records(for appPaths: Set<String>) -> [AppUsageRecord] {
        lock.lock()
        defer { lock.unlock() }
        return appPaths.compactMap { recordsByPath[$0] }
    }

    func allRecords() -> [AppUsageRecord] {
        lock.lock()
        defer { lock.unlock() }
        return Array(recordsByPath.values)
    }

    func reset() {
        lock.lock()
        recordsByPath.removeAll()
        lock.unlock()
        try? fileManager.removeItem(at: Self.storageURL(fileManager: fileManager))
    }

    private func persist(_ records: [String: AppUsageRecord]) {
        do {
            let url = Self.storageURL(fileManager: fileManager)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try Self.encoder.encode(records)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("LaunchNow: Failed to persist app usage records: \(error)")
        }
    }

    private static func loadRecords(from url: URL) throws -> [String: AppUsageRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        return try decoder.decode([String: AppUsageRecord].self, from: data)
    }

    private static func storageURL(fileManager: FileManager) -> URL {
        let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return (appSupport ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support"))
            .appendingPathComponent("LaunchNow", isDirectory: true)
            .appendingPathComponent("AppUsage.json", isDirectory: false)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
