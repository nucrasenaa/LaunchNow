import Foundation
import AppKit
import Combine
import SwiftData
import UniformTypeIdentifiers

enum LaunchpadSearchScope: String, CaseIterable, Identifiable {
    case launchNowApps
    case allApplications

    var id: String { rawValue }
}

private enum AutoOrganizeCategory: Int, CaseIterable {
    case developer
    case design
    case games
    case utilities
    case productivity
    case education
    case entertainment
    case music
    case photoVideo
    case social
    case finance
    case health
    case lifestyle
    case reference
    case other

    var title: String {
        let localization = LocalizationManager.shared
        switch self {
        case .developer: return localization.text(.categoryDeveloper)
        case .design: return localization.text(.categoryDesign)
        case .games: return localization.text(.categoryGames)
        case .utilities: return localization.text(.categoryUtilities)
        case .productivity: return localization.text(.categoryProductivity)
        case .education: return localization.text(.categoryEducation)
        case .entertainment: return localization.text(.categoryEntertainment)
        case .music: return localization.text(.categoryMusic)
        case .photoVideo: return localization.text(.categoryPhotoVideo)
        case .social: return localization.text(.categorySocial)
        case .finance: return localization.text(.categoryFinance)
        case .health: return localization.text(.categoryHealth)
        case .lifestyle: return localization.text(.categoryLifestyle)
        case .reference: return localization.text(.categoryReference)
        case .other: return localization.text(.categoryOther)
        }
    }
}

final class AppStore: ObservableObject {
    struct ProfileSummary: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var createdAt: Date
        var updatedAt: Date
    }

    private struct ProfileDocument: Codable {
        var summary: ProfileSummary
        var snapshot: ProfileSnapshot
    }

    private struct ProfileSnapshot: Codable {
        var settings: ProfileSettings
        var items: [ProfileItem]
        var customAppNames: [String: String]
        var customAppIconFiles: [String: String]
        var customFolderIconFiles: [String: String]
    }

    private struct ProfileSettings: Codable {
        var isFullscreenMode: Bool
        var scrollSensitivity: Double
        var gridColumns: Int
        var gridRows: Int
        var customApplicationSearchPaths: [String]
        var language: String
        var keyboardShortcut: String
        var searchScope: String?
        var appearancePreset: String
        var backgroundPreset: String
        var backgroundOpacity: Double
        var backgroundBlur: Double
        var customBackgroundImagePath: String?
    }

    private struct ProfileItem: Codable {
        var kind: String
        var appPath: String?
        var folderId: String?
        var folderName: String?
        var folderAppPaths: [String]
        var emptyId: String?
    }

    @Published var apps: [AppInfo] = []                  // แอปที่อยู่ใน Launchpad (ผู้ใช้เลือกแล้ว)
    @Published var availableApps: [AppInfo] = []         // แอปทั้งหมดที่สแกนเจอ ใช้เป็น source สำหรับ Import
    
    @Published var folders: [FolderInfo] = []
    @Published var items: [LaunchpadItem] = []
    @Published private(set) var profiles: [ProfileSummary] = []
    @Published private(set) var cloudBackupFolderPath: String?
    @Published private(set) var lastCloudBackupAt: Date?
    @Published var isSetting = false
    @Published var currentPage = 0
    @Published var searchText: String = ""
    @Published var searchScope: LaunchpadSearchScope = .launchNowApps {
        didSet {
            UserDefaults.standard.set(searchScope.rawValue, forKey: Self.searchScopeDefaultsKey)
            currentPage = 0
            triggerGridRefresh()
        }
    }
    @Published var isStartOnLogin: Bool = false
    @Published var isFullscreenMode: Bool = false {
        didSet {
            UserDefaults.standard.set(isFullscreenMode, forKey: "isFullscreenMode")
            DispatchQueue.main.async { [weak self] in
                if let appDelegate = AppDelegate.shared {
                    appDelegate.updateWindowMode(isFullscreen: self?.isFullscreenMode ?? false)
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.triggerGridRefresh()
            }
        }
    }
    
    @Published var scrollSensitivity: Double = 0.15 {
        didSet {
            UserDefaults.standard.set(scrollSensitivity, forKey: "scrollSensitivity")
        }
    }

    @Published var backgroundPreset: LaunchpadBackgroundPreset = .system {
        didSet {
            UserDefaults.standard.set(backgroundPreset.rawValue, forKey: Self.backgroundPresetDefaultsKey)
        }
    }

    @Published var appearancePreset: LaunchpadAppearancePreset = .glass {
        didSet {
            UserDefaults.standard.set(appearancePreset.rawValue, forKey: Self.appearancePresetDefaultsKey)
            triggerGridRefresh()
        }
    }

    @Published var backgroundOpacity: Double = 1.0 {
        didSet {
            let clamped = max(0.2, min(backgroundOpacity, 1.0))
            if backgroundOpacity != clamped { backgroundOpacity = clamped; return }
            UserDefaults.standard.set(backgroundOpacity, forKey: Self.backgroundOpacityDefaultsKey)
        }
    }

    @Published var backgroundBlur: Double = 0.0 {
        didSet {
            let clamped = max(0.0, min(backgroundBlur, 40.0))
            if backgroundBlur != clamped { backgroundBlur = clamped; return }
            UserDefaults.standard.set(backgroundBlur, forKey: Self.backgroundBlurDefaultsKey)
        }
    }

    @Published private(set) var customBackgroundImagePath: String? {
        didSet {
            UserDefaults.standard.set(customBackgroundImagePath, forKey: Self.customBackgroundImagePathDefaultsKey)
        }
    }

    var customBackgroundImageURL: URL? {
        customBackgroundImagePath.map { URL(fileURLWithPath: $0) }
    }
    
    // 新增：可配置的列/行数（用于 SettingsView）
    @Published var gridColumns: Int = 6 {
        didSet {
            let clamped = max(3, min(gridColumns, 12))
            if gridColumns != clamped { gridColumns = clamped; return }
            UserDefaults.standard.set(gridColumns, forKey: "gridColumns")
            applyGridChangeSideEffects()
        }
    }
    @Published var gridRows: Int = 4 {
        didSet {
            let clamped = max(2, min(gridRows, 8))
            if gridRows != clamped { gridRows = clamped; return }
            UserDefaults.standard.set(gridRows, forKey: "gridRows")
            applyGridChangeSideEffects()
        }
    }
    
    // 缓存管理器
    private let cacheManager = AppCacheManager.shared
    
    // 文件夹相关状态
    @Published var openFolder: FolderInfo? = nil
    @Published var isDragCreatingFolder = false
    @Published var folderCreationTarget: AppInfo? = nil
    @Published var openFolderActivatedByKeyboard: Bool = false
    @Published var isFolderNameEditing: Bool = false
    @Published var handoffDraggingApp: AppInfo? = nil
    @Published var handoffDragScreenLocation: CGPoint? = nil
    
    // 触发器
    @Published var folderUpdateTrigger: UUID = UUID()
    @Published var gridRefreshTrigger: UUID = UUID()
    
    var modelContext: ModelContext?

    // MARK: - Auto rescan (FSEvents)
    private var fsEventStream: FSEventStreamRef?
    private var pendingChangedAppPaths: Set<String> = []
    private var pendingForceFullScan: Bool = false
    private let fullRescanThreshold: Int = 50

    // 状态标记
    private var hasPerformedInitialScan: Bool = false
    private var cancellables: Set<AnyCancellable> = []
    private var hasAppliedOrderFromStore: Bool = false
    
    // 后台刷新队列与节流
    private let refreshQueue = DispatchQueue(label: "app.store.refresh", qos: .userInitiated)
    private var gridRefreshWorkItem: DispatchWorkItem?
    private var rescanWorkItem: DispatchWorkItem?
    private let fsEventsQueue = DispatchQueue(label: "app.store.fsevents")
    
    // 计算属性：每页项目数（由行列决定）
    var itemsPerPage: Int { max(1, gridColumns * gridRows) }
    
    let systemApplicationSearchPaths: [String] = [
        "/Applications",
        "\(NSHomeDirectory())/Applications",
        "/System/Applications",
        "/System/Cryptexes/App/System/Applications"
    ]
    
    @Published var customApplicationSearchPaths: [String] = [] {
        didSet {
            guard !isInitializingCustomPaths else { return }
            UserDefaults.standard.set(customApplicationSearchPaths, forKey: Self.customSearchPathsDefaultsKey)
            applicationSearchPathsDidChange()
        }
    }
    
    private static let customSearchPathsDefaultsKey = "customApplicationSearchPaths"
    private static let searchScopeDefaultsKey = "searchScope"
    private static let appearancePresetDefaultsKey = "appearancePreset"
    private static let backgroundPresetDefaultsKey = "backgroundPreset"
    private static let backgroundOpacityDefaultsKey = "backgroundOpacity"
    private static let backgroundBlurDefaultsKey = "backgroundBlur"
    private static let customBackgroundImagePathDefaultsKey = "customBackgroundImagePath"
    private static let cloudBackupFolderPathDefaultsKey = "cloudBackupFolderPath"
    private static let lastCloudBackupAtDefaultsKey = "lastCloudBackupAt"
    private var isInitializingCustomPaths = false
    
    private var applicationSearchPaths: [String] {
        var unique: [String] = []
        var seen = Set<String>()
        for path in systemApplicationSearchPaths {
            let normalized = Self.normalizePath(path)
            if seen.insert(normalized).inserted {
                unique.append(normalized)
            }
        }
        for path in customApplicationSearchPaths {
            let normalized = Self.normalizePath(path)
            if seen.insert(normalized).inserted {
                unique.append(normalized)
            }
        }
        return unique
    }
    
    private static func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }

    init() {
        // 读取持久化设置
        self.isFullscreenMode = UserDefaults.standard.bool(forKey: "isFullscreenMode")
        self.scrollSensitivity = UserDefaults.standard.double(forKey: "scrollSensitivity")
        if self.scrollSensitivity == 0.0 {
            self.scrollSensitivity = 0.15
        }
        let savedSearchScope = UserDefaults.standard.string(forKey: Self.searchScopeDefaultsKey) ?? LaunchpadSearchScope.launchNowApps.rawValue
        self.searchScope = LaunchpadSearchScope(rawValue: savedSearchScope) ?? .launchNowApps
        let savedBackgroundPreset = UserDefaults.standard.string(forKey: Self.backgroundPresetDefaultsKey) ?? LaunchpadBackgroundPreset.system.rawValue
        self.backgroundPreset = LaunchpadBackgroundPreset(rawValue: savedBackgroundPreset) ?? .system
        let savedAppearancePreset = UserDefaults.standard.string(forKey: Self.appearancePresetDefaultsKey) ?? LaunchpadAppearancePreset.glass.rawValue
        self.appearancePreset = LaunchpadAppearancePreset(rawValue: savedAppearancePreset) ?? .glass
        if let savedBackgroundOpacity = UserDefaults.standard.object(forKey: Self.backgroundOpacityDefaultsKey) as? Double {
            self.backgroundOpacity = max(0.2, min(savedBackgroundOpacity, 1.0))
        }
        if let savedBackgroundBlur = UserDefaults.standard.object(forKey: Self.backgroundBlurDefaultsKey) as? Double {
            self.backgroundBlur = max(0.0, min(savedBackgroundBlur, 40.0))
        }
        if let savedBackgroundPath = UserDefaults.standard.string(forKey: Self.customBackgroundImagePathDefaultsKey),
           FileManager.default.fileExists(atPath: savedBackgroundPath) {
            self.customBackgroundImagePath = savedBackgroundPath
        } else {
            self.customBackgroundImagePath = nil
        }
        let savedCols = UserDefaults.standard.integer(forKey: "gridColumns")
        let savedRows = UserDefaults.standard.integer(forKey: "gridRows")
        self.gridColumns = savedCols == 0 ? 6 : max(3, min(savedCols, 12))
        self.gridRows = savedRows == 0 ? 4 : max(2, min(savedRows, 8))
        if let savedCloudPath = UserDefaults.standard.string(forKey: Self.cloudBackupFolderPathDefaultsKey),
           !savedCloudPath.isEmpty {
            self.cloudBackupFolderPath = savedCloudPath
        }
        if let savedCloudBackupDate = UserDefaults.standard.object(forKey: Self.lastCloudBackupAtDefaultsKey) as? Date {
            self.lastCloudBackupAt = savedCloudBackupDate
        }
        
        isInitializingCustomPaths = true
        let storedCustomPaths = UserDefaults.standard.array(forKey: Self.customSearchPathsDefaultsKey) as? [String] ?? []
        let normalizedStored = storedCustomPaths.map { Self.normalizePath($0) }
        let systemSet = Set(systemApplicationSearchPaths.map { Self.normalizePath($0) })
        var uniqueCustom: [String] = []
        var seen = Set<String>()
        for path in normalizedStored {
            if path.isEmpty { continue }
            if systemSet.contains(path) { continue }
            if seen.insert(path).inserted {
                uniqueCustom.append(path)
            }
        }
        self.customApplicationSearchPaths = uniqueCustom
        isInitializingCustomPaths = false
        UserDefaults.standard.set(uniqueCustom, forKey: Self.customSearchPathsDefaultsKey)
        reloadProfiles()
    }

    private func applyGridChangeSideEffects() {
        // 当行列设置变化时：压缩每页空位到末尾，删除空白页，刷新、保存
        compactItemsWithinPages()
        removeEmptyPages()
        triggerGridRefresh()
        saveAllOrder()
        // 让缓存和 UI 同步
        refreshCacheAfterFolderOperation()
    }
    
    // MARK: - Application Sources Management
    func addCustomApplicationSearchPaths(from urls: [URL]) {
        guard !urls.isEmpty else { return }
        let systemSet = Set(systemApplicationSearchPaths.map { Self.normalizePath($0) })
        var current = customApplicationSearchPaths
        var existing = Set(current.map { Self.normalizePath($0) })
        var didChange = false
        for url in urls {
            let normalized = Self.normalizePath(url.path)
            if normalized.isEmpty { continue }
            if systemSet.contains(normalized) { continue }
            if existing.contains(normalized) { continue }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: normalized, isDirectory: &isDir), isDir.boolValue else { continue }
            current.append(normalized)
            existing.insert(normalized)
            didChange = true
        }
        if didChange {
            customApplicationSearchPaths = current
        }
    }
    
    func removeCustomApplicationSearchPath(_ path: String) {
        let normalized = Self.normalizePath(path)
        let updated = customApplicationSearchPaths.filter { $0 != normalized }
        if updated.count != customApplicationSearchPaths.count {
            customApplicationSearchPaths = updated
        }
    }
    
    func restoreDefaultApplicationSearchPaths() {
        if !customApplicationSearchPaths.isEmpty {
            customApplicationSearchPaths = []
        }
    }
    
    private func applicationSearchPathsDidChange() {
        pendingChangedAppPaths.removeAll()
        pendingForceFullScan = false
        stopAutoRescan()
        startAutoRescan()
        scanApplicationsWithOrderPreservation()
    }

    // MARK: - Profiles
    func reloadProfiles() {
        do {
            let directory = try profilesDirectoryURL()
            let profileDirectories = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            var loaded: [ProfileSummary] = []
            for profileDirectory in profileDirectories {
                let documentURL = profileDocumentURL(in: profileDirectory)
                guard FileManager.default.fileExists(atPath: documentURL.path) else { continue }
                let data = try Data(contentsOf: documentURL)
                let document = try JSONDecoder.profileDecoder.decode(ProfileDocument.self, from: data)
                loaded.append(document.summary)
            }
            profiles = loaded.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            profiles = []
        }
    }

    func saveCurrentProfile(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        do {
            saveAllOrder()

            let now = Date()
            let summary = ProfileSummary(id: UUID().uuidString, name: name, createdAt: now, updatedAt: now)
            let directory = try profileDirectoryURL(for: summary.id)
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try copyCurrentProfileAssets(to: directory)

            let document = ProfileDocument(summary: summary, snapshot: makeProfileSnapshot())
            let data = try JSONEncoder.prettyProfileEncoder.encode(document)
            try data.write(to: profileDocumentURL(in: directory), options: [.atomic])
            reloadProfiles()
        } catch {
            NSSound.beep()
        }
    }

    func renameProfile(id: String, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        do {
            let directory = try profileDirectoryURL(for: id)
            let documentURL = profileDocumentURL(in: directory)
            let data = try Data(contentsOf: documentURL)
            var document = try JSONDecoder.profileDecoder.decode(ProfileDocument.self, from: data)
            document.summary.name = name
            document.summary.updatedAt = Date()
            let encoded = try JSONEncoder.prettyProfileEncoder.encode(document)
            try encoded.write(to: documentURL, options: [.atomic])
            reloadProfiles()
        } catch {
            NSSound.beep()
        }
    }

    func deleteProfile(id: String) {
        do {
            let directory = try profileDirectoryURL(for: id)
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
            reloadProfiles()
        } catch {
            NSSound.beep()
        }
    }

    func applyProfile(id: String) {
        do {
            let directory = try profileDirectoryURL(for: id)
            let data = try Data(contentsOf: profileDocumentURL(in: directory))
            var document = try JSONDecoder.profileDecoder.decode(ProfileDocument.self, from: data)
            try restoreProfileAssets(from: directory, snapshot: document.snapshot)
            applyProfileSnapshot(document.snapshot)

            document.summary.updatedAt = Date()
            let encoded = try JSONEncoder.prettyProfileEncoder.encode(document)
            try encoded.write(to: profileDocumentURL(in: directory), options: [.atomic])
            reloadProfiles()
        } catch {
            NSSound.beep()
        }
    }

    func setCloudBackupFolder(_ url: URL) {
        let normalizedPath = Self.normalizePath(url.path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalizedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            NSSound.beep()
            return
        }
        cloudBackupFolderPath = normalizedPath
        UserDefaults.standard.set(normalizedPath, forKey: Self.cloudBackupFolderPathDefaultsKey)
    }

    func clearCloudBackupFolder() {
        cloudBackupFolderPath = nil
        lastCloudBackupAt = nil
        UserDefaults.standard.removeObject(forKey: Self.cloudBackupFolderPathDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.lastCloudBackupAtDefaultsKey)
    }

    func backupProfilesToCloud() -> Bool {
        do {
            saveAllOrder()
            let source = try profilesDirectoryURL()
            let destination = try cloudProfilesDirectoryURL()
            try copyDirectoryIfPresent(from: source, to: destination)
            try writeCloudBackupManifest()
            let now = Date()
            lastCloudBackupAt = now
            UserDefaults.standard.set(now, forKey: Self.lastCloudBackupAtDefaultsKey)
            return true
        } catch {
            NSSound.beep()
            return false
        }
    }

    func restoreProfilesFromCloud() -> Bool {
        do {
            let source = try cloudProfilesDirectoryURL()
            guard FileManager.default.fileExists(atPath: source.path) else {
                NSSound.beep()
                return false
            }
            let destination = try profilesDirectoryURL()
            try copyDirectoryIfPresent(from: source, to: destination)
            reloadProfiles()
            return true
        } catch {
            NSSound.beep()
            return false
        }
    }

    private func makeProfileSnapshot() -> ProfileSnapshot {
        ProfileSnapshot(
            settings: ProfileSettings(
                isFullscreenMode: isFullscreenMode,
                scrollSensitivity: scrollSensitivity,
                gridColumns: gridColumns,
                gridRows: gridRows,
                customApplicationSearchPaths: customApplicationSearchPaths,
                language: LocalizationManager.shared.language.rawValue,
                keyboardShortcut: KeyboardShortcutManager.shared.preset.rawValue,
                searchScope: searchScope.rawValue,
                appearancePreset: appearancePreset.rawValue,
                backgroundPreset: backgroundPreset.rawValue,
                backgroundOpacity: backgroundOpacity,
                backgroundBlur: backgroundBlur,
                customBackgroundImagePath: customBackgroundImagePath
            ),
            items: items.map(profileItemSnapshot(for:)),
            customAppNames: CustomAppNameManager.shared.exportNames(),
            customAppIconFiles: CustomAppIconManager.shared.exportIconFiles(),
            customFolderIconFiles: CustomFolderIconManager.shared.exportIconFiles()
        )
    }

    private func profileItemSnapshot(for item: LaunchpadItem) -> ProfileItem {
        switch item {
        case .app(let app):
            return ProfileItem(kind: "app", appPath: app.url.path, folderId: nil, folderName: nil, folderAppPaths: [], emptyId: nil)
        case .folder(let folder):
            return ProfileItem(kind: "folder", appPath: nil, folderId: folder.id, folderName: folder.name, folderAppPaths: folder.apps.map { $0.url.path }, emptyId: nil)
        case .empty(let id):
            return ProfileItem(kind: "empty", appPath: nil, folderId: nil, folderName: nil, folderAppPaths: [], emptyId: id)
        }
    }

    private func applyProfileSnapshot(_ snapshot: ProfileSnapshot) {
        let settings = snapshot.settings
        isFullscreenMode = settings.isFullscreenMode
        scrollSensitivity = settings.scrollSensitivity
        gridColumns = settings.gridColumns
        gridRows = settings.gridRows
        customApplicationSearchPaths = settings.customApplicationSearchPaths
        LocalizationManager.shared.language = AppLanguage(rawValue: settings.language) ?? .system
        if let keyboardPreset = KeyboardShortcutPreset(rawValue: settings.keyboardShortcut) {
            KeyboardShortcutManager.shared.setPreset(keyboardPreset)
        }
        if let rawSearchScope = settings.searchScope,
           let importedSearchScope = LaunchpadSearchScope(rawValue: rawSearchScope) {
            searchScope = importedSearchScope
        }
        if let preset = LaunchpadAppearancePreset(rawValue: settings.appearancePreset) {
            appearancePreset = preset
        }
        applyImportedBackgroundSettings(
            presetRawValue: settings.backgroundPreset,
            appearancePresetRawValue: settings.appearancePreset,
            opacity: settings.backgroundOpacity,
            blur: settings.backgroundBlur,
            customImagePath: settings.customBackgroundImagePath
        )

        var restoredFolders: [FolderInfo] = []
        var folderById: [String: FolderInfo] = [:]
        for item in snapshot.items where item.kind == "folder" {
            guard let folderId = item.folderId else { continue }
            let folderApps = item.folderAppPaths.compactMap(appInfoIfAvailable)
            let folder = FolderInfo(
                id: folderId,
                name: item.folderName ?? LocalizationManager.shared.text(.untitledFolder),
                apps: folderApps
            )
            restoredFolders.append(folder)
            folderById[folderId] = folder
        }

        let restoredItems: [LaunchpadItem] = snapshot.items.compactMap { item in
            switch item.kind {
            case "app":
                guard let path = item.appPath, let app = appInfoIfAvailable(path: path) else { return nil }
                return .app(app)
            case "folder":
                guard let folderId = item.folderId, let folder = folderById[folderId] else { return nil }
                return .folder(folder)
            case "empty":
                return .empty(item.emptyId ?? UUID().uuidString)
            default:
                return nil
            }
        }

        folders = restoredFolders
        items = restoredItems
        apps = uniqueApps(from: restoredItems)
        openFolder = nil
        currentPage = 0
        searchText = ""
        hasAppliedOrderFromStore = true
        triggerFolderUpdate()
        triggerGridRefresh()
        refreshCacheAfterFolderOperation()
        saveAllOrder()
    }

    private func appInfoIfAvailable(path: String) -> AppInfo? {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return appInfo(from: url)
    }

    private func uniqueApps(from items: [LaunchpadItem]) -> [AppInfo] {
        var result: [AppInfo] = []
        var seen = Set<String>()
        for item in items {
            switch item {
            case .app(let app):
                if seen.insert(app.url.path).inserted { result.append(app) }
            case .folder(let folder):
                for app in folder.apps where seen.insert(app.url.path).inserted {
                    result.append(app)
                }
            case .empty:
                break
            }
        }
        return result
    }

    private func copyCurrentProfileAssets(to profileDirectory: URL) throws {
        try copyDirectoryIfPresent(
            from: CustomAppIconManager.shared.exportIconsDirectoryURL(),
            to: profileDirectory.appendingPathComponent("CustomIcons", isDirectory: true)
        )
        try copyDirectoryIfPresent(
            from: CustomFolderIconManager.shared.exportIconsDirectoryURL(),
            to: profileDirectory.appendingPathComponent("CustomFolderIcons", isDirectory: true)
        )
        try copyDirectoryIfPresent(
            from: try backgroundDirectoryURL(),
            to: profileDirectory.appendingPathComponent("Backgrounds", isDirectory: true)
        )
    }

    private func restoreProfileAssets(from profileDirectory: URL, snapshot: ProfileSnapshot) throws {
        try CustomAppIconManager.shared.replaceIcons(
            with: snapshot.customAppIconFiles,
            from: profileDirectory.appendingPathComponent("CustomIcons", isDirectory: true)
        )
        try CustomFolderIconManager.shared.replaceIcons(
            with: snapshot.customFolderIconFiles,
            from: profileDirectory.appendingPathComponent("CustomFolderIcons", isDirectory: true)
        )
        CustomAppNameManager.shared.replaceNames(snapshot.customAppNames)

        let backgroundDestination = try backgroundDirectoryURL()
        if FileManager.default.fileExists(atPath: backgroundDestination.path) {
            try FileManager.default.removeItem(at: backgroundDestination)
        }
        try copyDirectoryIfPresent(
            from: profileDirectory.appendingPathComponent("Backgrounds", isDirectory: true),
            to: backgroundDestination
        )
    }

    private func copyDirectoryIfPresent(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { return }
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
    }

    private func profilesDirectoryURL() throws -> URL {
        let directory = try appSupportDirectoryURL().appendingPathComponent("Profiles", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func profileDirectoryURL(for id: String) throws -> URL {
        try profilesDirectoryURL().appendingPathComponent(id, isDirectory: true)
    }

    private func profileDocumentURL(in directory: URL) -> URL {
        directory.appendingPathComponent("Profile.json", conformingTo: .json)
    }

    private func cloudBackupRootURL() throws -> URL {
        guard let cloudBackupFolderPath else {
            throw CocoaError(.fileNoSuchFile)
        }
        let root = URL(fileURLWithPath: cloudBackupFolderPath)
            .appendingPathComponent("LaunchNow Backups", isDirectory: true)
        if !FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private func cloudProfilesDirectoryURL() throws -> URL {
        try cloudBackupRootURL().appendingPathComponent("Profiles", isDirectory: true)
    }

    private func writeCloudBackupManifest() throws {
        let manifestURL = try cloudBackupRootURL().appendingPathComponent("CloudBackup.json", conformingTo: .json)
        let manifest: [String: String] = [
            "app": "LaunchNow",
            "updatedAt": ISO8601DateFormatter().string(from: Date()),
            "profileCount": "\(profiles.count)"
        ]
        let data = try JSONEncoder.prettyProfileEncoder.encode(manifest)
        try data.write(to: manifestURL, options: [.atomic])
    }

    private func appSupportDirectoryURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = appSupport.appendingPathComponent("LaunchNow", isDirectory: true)
        if !fm.fileExists(atPath: directory.path) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // หากมี persisted order ให้โหลด (เพื่อคง layout เก่า) มิฉะนั้น ปล่อยว่างไว้จนผู้ใช้ Import
        if !hasAppliedOrderFromStore {
            loadAllOrder()
        }
        
        // เมื่อรายการแอปใน Launchpad (apps) มีข้อมูลและยังไม่เคย apply order จาก store ให้โหลดอีกครั้ง
        $apps
            .map { !$0.isEmpty }
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self else { return }
                if !self.hasAppliedOrderFromStore {
                    self.loadAllOrder()
                }
            }
            .store(in: &cancellables)
        
        // 监听items变化，自动保存排序
        $items
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.items.isEmpty else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.saveAllOrder()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Order Persistence
    func applyOrderAndFolders() {
        self.loadAllOrder()
    }

    // MARK: - Initial scan (once)
    func performInitialScanIfNeeded() {
        if !hasAppliedOrderFromStore {
            loadAllOrder()
        }
        hasPerformedInitialScan = true
        scanAvailableApplicationsOnly()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.generateCacheAfterScan()
        }
    }

    private func scanAvailableApplicationsOnly() {
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [AppInfo] = []
            var seenPaths = Set<String>()

            let scanQueue = DispatchQueue(label: "app.scan", attributes: .concurrent)
            let group = DispatchGroup()
            let lock = NSLock()
            
            for path in self.applicationSearchPaths {
                group.enter()
                scanQueue.async {
                    let url = URL(fileURLWithPath: path)
                    if let enumerator = FileManager.default.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) {
                        var localFound: [AppInfo] = []
                        var localSeenPaths = Set<String>()
                        for case let item as URL in enumerator {
                            let resolved = item.resolvingSymlinksInPath()
                            guard resolved.pathExtension == "app",
                                  self.isValidApp(at: resolved),
                                  !self.isInsideAnotherApp(resolved) else { continue }
                            if !localSeenPaths.contains(resolved.path) {
                                localSeenPaths.insert(resolved.path)
                                localFound.append(self.appInfo(from: resolved))
                            }
                        }
                        lock.lock()
                        found.append(contentsOf: localFound)
                        seenPaths.formUnion(localSeenPaths)
                        lock.unlock()
                    }
                    group.leave()
                }
            }
            group.wait()
            
            var uniqueApps: [AppInfo] = []
            var uniqueSeenPaths = Set<String>()
            for app in found {
                if !uniqueSeenPaths.contains(app.url.path) {
                    uniqueSeenPaths.insert(app.url.path)
                    uniqueApps.append(app)
                }
            }
            let sorted = uniqueApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.availableApps = sorted
                if self.hasAppliedOrderFromStore && !self.items.isEmpty {
                    self.rebuildItems()
                }
                self.generateCacheAfterScan()
            }
        }
    }
    
    // MARK: - Manual Import flow
    func presentImportPanelAndImport() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "app") ?? .applicationBundle]
        let localization = LocalizationManager.shared
        panel.prompt = localization.text(.import)
        panel.message = localization.text(.selectAppsToAdd)
        if AppPanelPresenter.runModal(panel) == .OK {
            let urls = panel.urls
            importSelectedApps(urls: urls)
        }
    }
    
    func importSelectedApps(urls: [URL]) {
        guard !urls.isEmpty else { return }
        var selected: [AppInfo] = []
        var seen = Set<String>()
        for url in urls {
            let resolved = url.resolvingSymlinksInPath()
            guard resolved.pathExtension == "app",
                  FileManager.default.fileExists(atPath: resolved.path),
                  isValidApp(at: resolved),
                  !isInsideAnotherApp(resolved)
            else { continue }
            if !seen.contains(resolved.path) {
                seen.insert(resolved.path)
                let info = appInfo(from: resolved)
                selected.append(info)
            }
        }
        guard !selected.isEmpty else { return }
        
        let existingPaths = Set(apps.map { $0.url.path })
        let toAdd = selected.filter { !existingPaths.contains($0.url.path) }
        if toAdd.isEmpty { return }
        
        apps.append(contentsOf: toAdd)
        for app in toAdd {
            if let emptyIdx = items.firstIndex(where: { if case .empty = $0 { return true } else { return false } }) {
                items[emptyIdx] = .app(app)
            } else {
                items.append(.app(app))
            }
        }
        compactItemsWithinPages()
        saveAllOrder()
        triggerFolderUpdate()
        triggerGridRefresh()
        refreshCacheAfterFolderOperation()
    }
    
    func importSelectedApps(fromAppInfos appsToImport: [AppInfo]) {
        guard !appsToImport.isEmpty else { return }
        let existingPaths = Set(apps.map { $0.url.path })
        let toAdd = appsToImport.filter { !existingPaths.contains($0.url.path) }
        guard !toAdd.isEmpty else { return }
        
        apps.append(contentsOf: toAdd)
        for app in toAdd {
            if let emptyIdx = items.firstIndex(where: { if case .empty = $0 { return true } else { return false } }) {
                items[emptyIdx] = .app(app)
            } else {
                items.append(.app(app))
            }
        }
        compactItemsWithinPages()
        saveAllOrder()
        triggerFolderUpdate()
        triggerGridRefresh()
        refreshCacheAfterFolderOperation()
    }
    
    func removeSelectedApps(fromAppInfos appsToRemove: [AppInfo]) {
        guard !appsToRemove.isEmpty else { return }
        let removePaths = Set(appsToRemove.map { $0.url.path })
        
        if !folders.isEmpty {
            for fIdx in folders.indices {
                folders[fIdx].apps.removeAll { removePaths.contains($0.url.path) }
            }
            folders.removeAll { $0.apps.isEmpty }
        }
        
        for idx in items.indices {
            switch items[idx] {
            case .app(let a):
                if removePaths.contains(a.url.path) {
                    items[idx] = .empty(UUID().uuidString)
                }
            case .folder(let folder):
                if folders.first(where: { $0.id == folder.id }) == nil {
                    items[idx] = .empty(UUID().uuidString)
                }
            case .empty:
                break
            }
        }
        
        apps.removeAll { removePaths.contains($0.url.path) }
        rebuildItems()
        compactItemsWithinPages()
        removeEmptyPages()
        saveAllOrder()
        triggerFolderUpdate()
        triggerGridRefresh()
        refreshCacheAfterFolderOperation()
    }
    
    func resetImportedApps() {
        openFolder = nil
        folders.removeAll()
        items.removeAll()
        apps.removeAll()
        CustomAppNameManager.shared.resetAll()
        clearAllPersistedData()
        cacheManager.clearAllCaches()
        triggerFolderUpdate()
        triggerGridRefresh()
    }

    func autoOrganizeApps() {
        let allApps = uniqueApps(from: items)
        guard !allApps.isEmpty else { return }

        var existingFoldersByName: [String: FolderInfo] = [:]
        for folder in folders where existingFoldersByName[folder.name] == nil {
            existingFoldersByName[folder.name] = folder
        }
        var grouped: [AutoOrganizeCategory: [AppInfo]] = [:]
        for app in allApps {
            grouped[autoOrganizeCategory(for: app), default: []].append(app)
        }

        var organizedItems: [LaunchpadItem] = []
        var organizedFolders: [FolderInfo] = []
        var freeApps: [AppInfo] = []

        for category in AutoOrganizeCategory.allCases {
            guard var categoryApps = grouped[category], !categoryApps.isEmpty else { continue }
            categoryApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            if categoryApps.count == 1, let app = categoryApps.first {
                organizedItems.append(.app(app))
                freeApps.append(app)
                continue
            }

            let title = category.title
            let folder: FolderInfo
            if let existing = existingFoldersByName[title] {
                folder = FolderInfo(id: existing.id, name: existing.name, apps: categoryApps, createdAt: existing.createdAt)
            } else {
                folder = FolderInfo(name: title, apps: categoryApps)
            }
            organizedFolders.append(folder)
            organizedItems.append(.folder(folder))
        }

        let ipp = itemsPerPage
        if !organizedItems.isEmpty {
            let remainder = organizedItems.count % ipp
            if remainder != 0 {
                for _ in 0..<(ipp - remainder) {
                    organizedItems.append(.empty(UUID().uuidString))
                }
            }
        }

        openFolder = nil
        folders = organizedFolders
        items = organizedItems
        apps = freeApps
        currentPage = 0
        searchText = ""
        saveAllOrder()
        triggerFolderUpdate()
        triggerGridRefresh()
        refreshCacheAfterFolderOperation()
    }

    private func autoOrganizeCategory(for app: AppInfo) -> AutoOrganizeCategory {
        let identifier = app.bundleCategoryIdentifier ?? ""
        switch identifier {
        case "public.app-category.developer-tools":
            return .developer
        case "public.app-category.graphics-design":
            return .design
        case "public.app-category.games":
            return .games
        case "public.app-category.utilities":
            return .utilities
        case "public.app-category.productivity", "public.app-category.business":
            return .productivity
        case "public.app-category.education":
            return .education
        case "public.app-category.entertainment", "public.app-category.news", "public.app-category.sports":
            return .entertainment
        case "public.app-category.music":
            return .music
        case "public.app-category.photography", "public.app-category.video":
            return .photoVideo
        case "public.app-category.social-networking":
            return .social
        case "public.app-category.finance":
            return .finance
        case "public.app-category.healthcare-fitness", "public.app-category.medical":
            return .health
        case "public.app-category.lifestyle", "public.app-category.travel", "public.app-category.weather":
            return .lifestyle
        case "public.app-category.reference":
            return .reference
        default:
            return fallbackAutoOrganizeCategory(for: app)
        }
    }

    private func fallbackAutoOrganizeCategory(for app: AppInfo) -> AutoOrganizeCategory {
        let haystack = "\(app.name) \(app.url.path)".lowercased()
        let developerHints = ["xcode", "terminal", "iterm", "visual studio", "vscode", "cursor", "android studio", "docker", "postman", "github", "sourcetree", "fork", "tower", "simulator", "code"]
        let designHints = ["figma", "sketch", "adobe", "photoshop", "illustrator", "indesign", "canva", "affinity", "principle"]
        let gameHints = ["steam", "epic games", "battle.net", "minecraft", "game"]
        let utilityHints = ["clean", "unarchiver", "istat", "raycast", "alfred", "magnet", "rectangle", "bartender", "karabiner", "utility"]
        let productivityHints = ["notion", "obsidian", "things", "todoist", "calendar", "mail", "notes", "numbers", "pages", "keynote", "word", "excel", "powerpoint", "slack", "zoom", "teams"]
        let musicHints = ["music", "spotify", "garageband", "logic", "audacity"]
        let photoVideoHints = ["photo", "camera", "final cut", "imovie", "premiere", "davinci", "lightroom", "capture"]
        let socialHints = ["discord", "telegram", "line", "whatsapp", "messenger", "twitter", "x.app"]

        if developerHints.contains(where: haystack.contains) { return .developer }
        if designHints.contains(where: haystack.contains) { return .design }
        if gameHints.contains(where: haystack.contains) { return .games }
        if utilityHints.contains(where: haystack.contains) { return .utilities }
        if productivityHints.contains(where: haystack.contains) { return .productivity }
        if musicHints.contains(where: haystack.contains) { return .music }
        if photoVideoHints.contains(where: haystack.contains) { return .photoVideo }
        if socialHints.contains(where: haystack.contains) { return .social }
        return .other
    }

    func scanApplications(loadPersistedOrder: Bool = true) {
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [AppInfo] = []
            var seenPaths = Set<String>()

            for path in self.applicationSearchPaths {
                let url = URL(fileURLWithPath: path)
                
                if let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    for case let item as URL in enumerator {
                        let resolved = item.resolvingSymlinksInPath()
                        guard resolved.pathExtension == "app",
                              self.isValidApp(at: resolved),
                              !self.isInsideAnotherApp(resolved) else { continue }
                        if !seenPaths.contains(resolved.path) {
                            seenPaths.insert(resolved.path)
                            found.append(self.appInfo(from: resolved))
                        }
                    }
                }
            }

            let sorted = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async {
                self.availableApps = sorted
                if loadPersistedOrder {
                    self.rebuildItems()
                    self.loadAllOrder()
                }
                self.generateCacheAfterScan()
            }
        }
    }
    
    func scanApplicationsWithOrderPreservation() {
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [AppInfo] = []
            var seenPaths = Set<String>()

            let scanQueue = DispatchQueue(label: "app.scan", attributes: .concurrent)
            let group = DispatchGroup()
            let lock = NSLock()
            
            for path in self.applicationSearchPaths {
                group.enter()
                scanQueue.async {
                    let url = URL(fileURLWithPath: path)
                    
                    if let enumerator = FileManager.default.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) {
                        var localFound: [AppInfo] = []
                        var localSeenPaths = Set<String>()
                        
                        for case let item as URL in enumerator {
                            let resolved = item.resolvingSymlinksInPath()
                            guard resolved.pathExtension == "app",
                                  self.isValidApp(at: resolved),
                                  !self.isInsideAnotherApp(resolved) else { continue }
                            if !localSeenPaths.contains(resolved.path) {
                                localSeenPaths.insert(resolved.path)
                                localFound.append(self.appInfo(from: resolved))
                            }
                        }
                        
                        lock.lock()
                        found.append(contentsOf: localFound)
                        seenPaths.formUnion(localSeenPaths)
                        lock.unlock()
                    }
                    group.leave()
                }
            }
            group.wait()
            
            var uniqueApps: [AppInfo] = []
            var uniqueSeenPaths = Set<String>()
            for app in found {
                if !uniqueSeenPaths.contains(app.url.path) {
                    uniqueSeenPaths.insert(app.url.path)
                    uniqueApps.append(app)
                }
            }
            
            DispatchQueue.main.async {
                self.availableApps = uniqueApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                if self.hasAppliedOrderFromStore {
                    self.processScannedApplicationsForPersistedLayout(self.availableApps)
                }
                self.generateCacheAfterScan()
            }
        }
    }
    
    private func processScannedApplicationsForPersistedLayout(_ allApps: [AppInfo]) {
        let allPaths = Set(allApps.map { $0.url.path })
        for app in apps {
            if !allPaths.contains(app.url.path) {
                removeDeletedApp(app)
            }
        }
        apps.removeAll { !allPaths.contains($0.url.path) }
        let map = Dictionary(uniqueKeysWithValues: allApps.map { ($0.url.path, $0) })
        for i in apps.indices {
            if let updated = map[apps[i].url.path] {
                apps[i] = updated
            }
        }
        for fIdx in folders.indices {
            for aIdx in folders[fIdx].apps.indices {
                let path = folders[fIdx].apps[aIdx].url.path
                if let updated = map[path] {
                    folders[fIdx].apps[aIdx] = updated
                }
            }
        }
        for idx in items.indices {
            if case .app(let a) = items[idx], let updated = map[a.url.path] {
                items[idx] = .app(updated)
            }
        }
        compactItemsWithinPages()
        saveAllOrder()
        triggerFolderUpdate()
        triggerGridRefresh()
    }
    
    private func removeDeletedApp(_ deletedApp: AppInfo) {
        for folderIndex in self.folders.indices {
            self.folders[folderIndex].apps.removeAll { $0 == deletedApp }
        }
        self.folders.removeAll { $0.apps.isEmpty }
        for itemIndex in self.items.indices {
            if case let .app(app) = self.items[itemIndex], app == deletedApp {
                self.items[itemIndex] = .empty(UUID().uuidString)
            }
        }
    }
    
    private func rebuildItemsWithStrictOrderPreservation(currentItems: [LaunchpadItem]) {
        var newItems: [LaunchpadItem] = []
        let appsInFolders = Set(self.folders.flatMap { $0.apps })
        for (_, item) in currentItems.enumerated() {
            switch item {
            case .folder(let folder):
                if self.folders.contains(where: { $0.id == folder.id }) {
                    if let updatedFolder = self.folders.first(where: { $0.id == folder.id }) {
                        newItems.append(.folder(updatedFolder))
                    } else {
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else {
                    newItems.append(.empty(UUID().uuidString))
                }
            case .app(let app):
                if self.apps.contains(where: { $0.url.path == app.url.path }) {
                    if !appsInFolders.contains(app) {
                        newItems.append(.app(app))
                    } else {
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else {
                    newItems.append(.empty(UUID().uuidString))
                }
            case .empty(let token):
                newItems.append(.empty(token))
            }
        }
        let existingAppPaths = Set(newItems.compactMap { item in
            if case let .app(app) = item { return app.url.path } else { return nil }
        })
        let newFreeApps = self.apps.filter { app in
            !appsInFolders.contains(app) && !existingAppPaths.contains(app.url.path)
        }
        if !newFreeApps.isEmpty {
            let ipp = self.itemsPerPage
            let currentPages = (newItems.count + ipp - 1) / ipp
            let lastPageStart = currentPages > 0 ? (currentPages - 1) * ipp : 0
            let lastPageEnd = newItems.count
            if lastPageEnd < lastPageStart + ipp {
                for app in newFreeApps { newItems.append(.app(app)) }
            } else {
                let remainingSlots = ipp - (lastPageEnd - lastPageStart)
                for _ in 0..<remainingSlots { newItems.append(.empty(UUID().uuidString)) }
                for app in newFreeApps { newItems.append(.app(app)) }
            }
        }
        self.items = newItems
    }
    
    private func smartRebuildItemsWithOrderPreservation(currentItems: [LaunchpadItem], newApps: [AppInfo]) {
        let hasPersistedData = self.hasPersistedOrderData()
        if hasPersistedData {
            self.mergeCurrentOrderWithPersistedData(currentItems: currentItems, newApps: newApps)
        } else {
            if !self.apps.isEmpty {
                self.rebuildFromScannedApps(newApps: [])
            }
        }
    }
    
    private func hasPersistedOrderData() -> Bool {
        guard let modelContext = self.modelContext else { return false }
        do {
            let pageEntries = try modelContext.fetch(FetchDescriptor<PageEntryData>())
            let topItems = try modelContext.fetch(FetchDescriptor<TopItemData>())
            return !pageEntries.isEmpty || !topItems.isEmpty
        } catch {
            return false
        }
    }
    
    private func mergeCurrentOrderWithPersistedData(currentItems: [LaunchpadItem], newApps: [AppInfo]) {
        var newItems: [LaunchpadItem] = []
        let appsInFolders = Set(self.folders.flatMap { $0.apps })
        for (_, item) in currentItems.enumerated() {
            switch item {
            case .folder(let folder):
                if self.folders.contains(where: { $0.id == folder.id }) {
                    if let updatedFolder = self.folders.first(where: { $0.id == folder.id }) {
                        newItems.append(.folder(updatedFolder))
                    } else {
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else {
                    newItems.append(.empty(UUID().uuidString))
                }
            case .app(let app):
                if self.apps.contains(where: { $0.url.path == app.url.path }) {
                    if !appsInFolders.contains(app) {
                        newItems.append(.app(app))
                    } else {
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else {
                    newItems.append(.empty(UUID().uuidString))
                }
            case .empty(let token):
                newItems.append(.empty(token))
            }
        }
        let existingAppPaths = Set(newItems.compactMap { item in
            if case let .app(app) = item { return app.url.path } else { return nil }
        })
        let newFreeApps = self.apps.filter { app in
            !appsInFolders.contains(app) && !existingAppPaths.contains(app.url.path)
        }
        if !newFreeApps.isEmpty {
            let ipp = self.itemsPerPage
            let currentPages = (newItems.count + ipp - 1) / ipp
            let lastPageStart = currentPages > 0 ? (currentPages - 1) * ipp : 0
            let lastPageEnd = newItems.count
            if lastPageEnd < lastPageStart + ipp {
                for app in newFreeApps { newItems.append(.app(app)) }
            } else {
                let remainingSlots = ipp - (lastPageEnd - lastPageStart)
                for _ in 0..<remainingSlots { newItems.append(.empty(UUID().uuidString)) }
                for app in newFreeApps { newItems.append(.app(app)) }
            }
        }
        self.items = newItems
    }
    
    private func rebuildFromScannedApps(newApps: [AppInfo]) {
        var newItems: [LaunchpadItem] = []
        let appsInFolders = Set(self.folders.flatMap { $0.apps })
        let freeApps = self.apps.filter { !appsInFolders.contains($0) }
        for app in freeApps { newItems.append(.app(app)) }
        for folder in self.folders { newItems.append(.folder(folder)) }
        for app in newApps {
            if !appsInFolders.contains(app) && !freeApps.contains(app) {
                newItems.append(.app(app))
            }
        }
        let ipp = self.itemsPerPage
        let currentPages = (newItems.count + ipp - 1) / ipp
        let lastPageStart = currentPages > 0 ? (currentPages - 1) * ipp : 0
        let lastPageEnd = newItems.count
        if lastPageEnd < lastPageStart + ipp {
            let remainingSlots = ipp - (lastPageEnd - lastPageStart)
            for _ in 0..<remainingSlots { newItems.append(.empty(UUID().uuidString)) }
        }
        self.items = newItems
    }
    
    private func loadFoldersFromPersistedData() {
        guard let modelContext = self.modelContext else { return }
        do {
            let saved = try modelContext.fetch(FetchDescriptor<PageEntryData>(
                sortBy: [SortDescriptor(\.pageIndex, order: .forward), SortDescriptor(\.position, order: .forward)]
            ))
            if !saved.isEmpty {
                var folderMap: [String: FolderInfo] = [:]
                var foldersInOrder: [FolderInfo] = []
                for row in saved where row.kind == "folder" {
                    guard let fid = row.folderId else { continue }
                    if folderMap[fid] != nil { continue }
                    let folderApps: [AppInfo] = row.appPaths.compactMap { path in
                        if let existing = apps.first(where: { $0.url.path == path }) {
                            return existing
                        }
                        let url = URL(fileURLWithPath: path)
                        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                        return self.appInfo(from: url)
                    }
                    let folder = FolderInfo(id: fid, name: row.folderName ?? LocalizationManager.shared.text(.untitledFolder), apps: folderApps, createdAt: row.createdAt)
                    folderMap[fid] = folder
                    foldersInOrder.append(folder)
                }
                self.folders = foldersInOrder
            }
        } catch {
        }
    }

    deinit {
        stopAutoRescan()
    }

    // MARK: - FSEvents wiring
    func startAutoRescan() {
        guard fsEventStream == nil else { return }
        let candidates = applicationSearchPaths
        let pathsToWatch: [String] = candidates.filter { path in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        }
        guard !pathsToWatch.isEmpty else { return }
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { (streamRef, clientInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let info = clientInfo else { return }
            let appStore = Unmanaged<AppStore>.fromOpaque(info).takeUnretainedValue()
            guard numEvents > 0 else {
                appStore.handleFSEvents(paths: [], flagsPointer: eventFlags, count: 0)
                return
            }
            let cfArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
            let nsArray = cfArray as NSArray
            guard let pathsArray = nsArray as? [String] else { return }
            appStore.handleFSEvents(paths: pathsArray, flagsPointer: eventFlags, count: numEvents)
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes)
        let latency: CFTimeInterval = 0.0
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context,
            pathsToWatch as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency, flags
        ) else { return }
        fsEventStream = stream
        FSEventStreamSetDispatchQueue(stream, fsEventsQueue)
        FSEventStreamStart(stream)
    }

    func stopAutoRescan() {
        guard let stream = fsEventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        fsEventStream = nil
    }

    private func handleFSEvents(paths: [String], flagsPointer: UnsafePointer<FSEventStreamEventFlags>?, count: Int) {
        let maxCount = min(paths.count, count)
        var localForceFull = false
        for i in 0..<maxCount {
            let rawPath = paths[i]
            let flags = flagsPointer?[i] ?? 0
            let created = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)) != 0
            let removed = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0
            let renamed = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)) != 0
            let modified = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)) != 0
            let isDir = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir)) != 0

            if isDir && (created || removed || renamed), applicationSearchPaths.contains(where: { rawPath.hasPrefix($0) }) {
                localForceFull = true
                break
            }
            guard let appBundlePath = self.canonicalAppBundlePath(for: rawPath) else { continue }
            if created || removed || renamed || modified {
                pendingChangedAppPaths.insert(appBundlePath)
            }
        }
        if localForceFull { pendingForceFullScan = true }
        scheduleRescan()
    }

    private func scheduleRescan() {
        rescanWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.performImmediateRefresh() }
        rescanWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func performImmediateRefresh() {
        if pendingForceFullScan || pendingChangedAppPaths.count > fullRescanThreshold {
            pendingForceFullScan = false
            pendingChangedAppPaths.removeAll()
            scanApplications(loadPersistedOrder: hasAppliedOrderFromStore)
            return
        }
        let changed = pendingChangedAppPaths
        pendingChangedAppPaths.removeAll()
        if !changed.isEmpty {
            applyIncrementalChanges(for: changed)
        }
    }

    private func applyIncrementalChanges(for changedPaths: Set<String>) {
        guard !changedPaths.isEmpty else { return }
        let snapshotApps = self.availableApps
        refreshQueue.async { [weak self] in
            guard let self else { return }
            enum PendingChange { case insert(AppInfo), update(AppInfo), remove(String) }
            var changes: [PendingChange] = []
            var pathToIndex: [String: Int] = [:]
            for (idx, app) in snapshotApps.enumerated() { pathToIndex[app.url.path] = idx }
            for path in changedPaths {
                let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
                let exists = FileManager.default.fileExists(atPath: url.path)
                let valid = exists && self.isValidApp(at: url) && !self.isInsideAnotherApp(url)
                if valid {
                    let info = self.appInfo(from: url)
                    if pathToIndex[url.path] != nil { changes.append(.update(info)) }
                    else { changes.append(.insert(info)) }
                } else {
                    changes.append(.remove(url.path))
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if changes.contains(where: { if case .remove = $0 { return true } else { return false } }) {
                    var indicesToRemove: [Int] = []
                    var map: [String: Int] = [:]
                    for (idx, app) in self.availableApps.enumerated() { map[app.url.path] = idx }
                    for change in changes {
                        if case .remove(let path) = change, let idx = map[path] { indicesToRemove.append(idx) }
                    }
                    for idx in indicesToRemove.sorted(by: >) { _ = self.availableApps.remove(at: idx) }
                }
                let updates: [AppInfo] = changes.compactMap { if case .update(let info) = $0 { return info } else { return nil } }
                if !updates.isEmpty {
                    var map: [String: Int] = [:]
                    for (idx, app) in self.availableApps.enumerated() { map[app.url.path] = idx }
                    for info in updates {
                        if let idx = map[info.url.path], self.availableApps.indices.contains(idx) { self.availableApps[idx] = info }
                    }
                }
                let inserts: [AppInfo] = changes.compactMap { if case .insert(let info) = $0 { return info } else { return nil } }
                if !inserts.isEmpty {
                    self.availableApps.append(contentsOf: inserts)
                    self.availableApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                }
                
                if self.hasAppliedOrderFromStore {
                    for change in changes {
                        if case .remove(let path) = change {
                            if let app = self.apps.first(where: { $0.url.path == path }) {
                                self.removeDeletedApp(app)
                                self.apps.removeAll { $0.url.path == path }
                            }
                        }
                    }
                    for info in updates {
                        if let idx = self.apps.firstIndex(where: { $0.url.path == info.url.path }) {
                            self.apps[idx] = info
                        }
                        for fIdx in self.folders.indices {
                            for aIdx in self.folders[fIdx].apps.indices where self.folders[fIdx].apps[aIdx].url.path == info.url.path {
                                self.folders[fIdx].apps[aIdx] = info
                            }
                        }
                        for iIdx in self.items.indices {
                            if case .app(let a) = self.items[iIdx], a.url.path == info.url.path { self.items[iIdx] = .app(info) }
                        }
                    }
                    self.compactItemsWithinPages()
                    self.rebuildItems()
                }
                
                self.triggerFolderUpdate()
                self.triggerGridRefresh()
                self.saveAllOrder()
                self.updateCacheAfterChanges()
            }
        }
    }

    private func canonicalAppBundlePath(for rawPath: String) -> String? {
        guard let range = rawPath.range(of: ".app") else { return nil }
        let end = rawPath.index(range.lowerBound, offsetBy: 4)
        let bundlePath = String(rawPath[..<end])
        return bundlePath
    }

    private func isInsideAnotherApp(_ url: URL) -> Bool {
        let appCount = url.pathComponents.filter { $0.hasSuffix(".app") }.count
        return appCount > 1
    }

    private func isValidApp(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path) &&
        NSWorkspace.shared.isFilePackage(atPath: url.path)
    }

    private func appInfo(from url: URL) -> AppInfo {
        return AppInfo.from(url: url)
    }

    // MARK: - Custom App Icons
    func presentChangeIconPanel(for app: AppInfo) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = LocalizationManager.shared.text(.choose)
        panel.message = LocalizationManager.shared.text(.chooseCustomIcon)
        if AppPanelPresenter.runModal(panel) == .OK, let iconURL = panel.url {
            do {
                try CustomAppIconManager.shared.setCustomIcon(from: iconURL, forAppPath: app.url.path)
                refreshAppInfo(forAppPath: app.url.path)
            } catch {
                NSSound.beep()
            }
        }
    }

    func presentChangeFolderIconPanel(for folder: FolderInfo) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = LocalizationManager.shared.text(.choose)
        panel.message = LocalizationManager.shared.text(.chooseCustomFolderIcon)
        if AppPanelPresenter.runModal(panel) == .OK, let iconURL = panel.url {
            do {
                try CustomFolderIconManager.shared.setCustomIcon(from: iconURL, forFolderId: folder.id)
                refreshFolderIcon(forFolderId: folder.id)
            } catch {
                NSSound.beep()
            }
        }
    }

    // MARK: - Custom Background
    func presentChooseBackgroundImagePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = LocalizationManager.shared.text(.choose)
        panel.message = LocalizationManager.shared.text(.chooseBackgroundImage)
        if AppPanelPresenter.runModal(panel) == .OK, let imageURL = panel.url {
            do {
                try setCustomBackgroundImage(from: imageURL)
            } catch {
                NSSound.beep()
            }
        }
    }

    func resetCustomBackgroundImage() {
        if let url = customBackgroundImageURL {
            try? FileManager.default.removeItem(at: url)
        }
        customBackgroundImagePath = nil
        if backgroundPreset == .customImage {
            backgroundPreset = .system
        }
    }

    func applyImportedBackgroundSettings(
        presetRawValue: String?,
        appearancePresetRawValue: String?,
        opacity: Double?,
        blur: Double?,
        customImagePath: String?
    ) {
        if let appearancePresetRawValue,
           let preset = LaunchpadAppearancePreset(rawValue: appearancePresetRawValue) {
            appearancePreset = preset
        }
        if let presetRawValue,
           let preset = LaunchpadBackgroundPreset(rawValue: presetRawValue) {
            backgroundPreset = preset
        }
        if let opacity {
            backgroundOpacity = opacity
        }
        if let blur {
            backgroundBlur = blur
        }
        if let customImagePath,
           FileManager.default.fileExists(atPath: customImagePath) {
            customBackgroundImagePath = customImagePath
        } else if let importedImageURL = try? firstBackgroundImageURL() {
            customBackgroundImagePath = importedImageURL.path
        }
    }

    func applyAppearancePreset(_ preset: LaunchpadAppearancePreset) {
        appearancePreset = preset

        switch preset {
        case .glass:
            backgroundPreset = .system
            backgroundOpacity = 1.0
            backgroundBlur = 0
        case .dark:
            backgroundPreset = .graphite
            backgroundOpacity = 0.9
            backgroundBlur = 10
        case .light:
            backgroundPreset = .aurora
            backgroundOpacity = 0.82
            backgroundBlur = 4
        case .compact:
            backgroundPreset = .system
            backgroundOpacity = 1.0
            backgroundBlur = 0
        case .classicLaunchpad:
            isFullscreenMode = true
            backgroundPreset = .aurora
            backgroundOpacity = 0.92
            backgroundBlur = 14
        }
    }

    private func setCustomBackgroundImage(from sourceURL: URL) throws {
        let destinationDirectory = try backgroundDirectoryURL()
        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let destinationURL = destinationDirectory.appendingPathComponent("background.\(fileExtension)")

        let fm = FileManager.default
        let existingFiles = (try? fm.contentsOfDirectory(at: destinationDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in existingFiles {
            try? fm.removeItem(at: file)
        }
        try fm.copyItem(at: sourceURL, to: destinationURL)
        customBackgroundImagePath = destinationURL.path
        backgroundPreset = .customImage
    }

    private func backgroundDirectoryURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = appSupport
            .appendingPathComponent("LaunchNow", isDirectory: true)
            .appendingPathComponent("Backgrounds", isDirectory: true)
        if !fm.fileExists(atPath: directory.path) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func firstBackgroundImageURL() throws -> URL? {
        let directory = try backgroundDirectoryURL()
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("background.") }
    }

    func resetCustomFolderIcon(for folder: FolderInfo) {
        CustomFolderIconManager.shared.resetCustomIcon(forFolderId: folder.id)
        refreshFolderIcon(forFolderId: folder.id)
    }

    func hasCustomFolderIcon(for folder: FolderInfo) -> Bool {
        CustomFolderIconManager.shared.hasCustomIcon(forFolderId: folder.id)
    }

    private func refreshFolderIcon(forFolderId folderId: String) {
        cacheManager.clearAllCaches()
        triggerFolderUpdate()
        triggerGridRefresh()
        if let openFolder, openFolder.id == folderId {
            self.openFolder = folders.first(where: { $0.id == folderId }) ?? openFolder
        }
    }

    func resetCustomIcon(for app: AppInfo) {
        CustomAppIconManager.shared.resetCustomIcon(forAppPath: app.url.path)
        refreshAppInfo(forAppPath: app.url.path)
    }

    func hasCustomIcon(for app: AppInfo) -> Bool {
        CustomAppIconManager.shared.hasCustomIcon(forAppPath: app.url.path)
    }

    // MARK: - Custom App Names
    func presentRenameAppPanel(for app: AppInfo) {
        let alert = NSAlert()
        alert.messageText = LocalizationManager.shared.text(.renameApp)
        alert.informativeText = LocalizationManager.shared.text(.renameAppDescription)
        alert.addButton(withTitle: LocalizationManager.shared.text(.save))
        alert.addButton(withTitle: LocalizationManager.shared.text(.cancel))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        textField.stringValue = app.name
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        if alert.runModal() == .alertFirstButtonReturn {
            renameAppDisplayName(app, newName: textField.stringValue)
        }
    }

    func renameAppDisplayName(_ app: AppInfo, newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            NSSound.beep()
            return
        }

        CustomAppNameManager.shared.setCustomName(trimmedName, forAppPath: app.url.path)
        refreshAppInfo(forAppPath: app.url.path)
    }

    func resetAppDisplayName(for app: AppInfo) {
        CustomAppNameManager.shared.resetCustomName(forAppPath: app.url.path)
        refreshAppInfo(forAppPath: app.url.path)
    }

    func hasCustomDisplayName(for app: AppInfo) -> Bool {
        CustomAppNameManager.shared.hasCustomName(forAppPath: app.url.path)
    }

    private func refreshAppInfo(forAppPath appPath: String) {
        let url = URL(fileURLWithPath: appPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let refreshed = appInfo(from: url)

        replaceAppInfo(refreshed, in: &availableApps)
        replaceAppInfo(refreshed, in: &apps)

        for folderIndex in folders.indices {
            replaceAppInfo(refreshed, in: &folders[folderIndex].apps)
        }

        for itemIndex in items.indices {
            switch items[itemIndex] {
            case .app(let app) where app.url.path == appPath:
                items[itemIndex] = .app(refreshed)
            case .folder(let folder):
                if let updatedFolder = folders.first(where: { $0.id == folder.id }) {
                    items[itemIndex] = .folder(updatedFolder)
                }
            case .app, .empty:
                break
            }
        }

        triggerFolderUpdate()
        triggerGridRefresh()
        refreshCacheAfterFolderOperation()
        saveAllOrder()
    }

    private func replaceAppInfo(_ app: AppInfo, in list: inout [AppInfo]) {
        for index in list.indices where list[index].url.path == app.url.path {
            list[index] = app
        }
    }
    
    // MARK: - 文件夹管理
    func createFolder(with apps: [AppInfo], name: String = LocalizationManager.shared.text(.untitledFolder)) -> FolderInfo {
        return createFolder(with: apps, name: name, insertAt: nil)
    }

    func createFolder(with apps: [AppInfo], name: String = LocalizationManager.shared.text(.untitledFolder), insertAt insertIndex: Int?) -> FolderInfo {
        let folder = FolderInfo(name: name, apps: apps)
        folders.append(folder)
        for app in apps {
            if let index = self.apps.firstIndex(of: app) {
                self.apps.remove(at: index)
            }
        }
        var newItems = self.items
        var indices: [Int] = []
        for (idx, item) in newItems.enumerated() {
            if case let .app(a) = item, apps.contains(a) { indices.append(idx) }
            if indices.count == apps.count { break }
        }
        for idx in indices { newItems[idx] = .empty(UUID().uuidString) }
        let baseIndex = indices.min() ?? min(newItems.count - 1, max(0, insertIndex ?? (newItems.count - 1)))
        let desiredIndex = insertIndex ?? baseIndex
        let safeIndex = min(max(0, desiredIndex), max(0, newItems.count - 1))
        if newItems.isEmpty {
            newItems = [.folder(folder)]
        } else {
            newItems[safeIndex] = .folder(folder)
        }
        self.items = newItems
        compactItemsWithinPages()
        DispatchQueue.main.async { [weak self] in self?.triggerFolderUpdate() }
        triggerGridRefresh()
        refreshCacheAfterFolderOperation()
        saveAllOrder()
        return folder
    }
    
    func addAppToFolder(_ app: AppInfo, folder: FolderInfo) {
        guard let folderIndex = folders.firstIndex(of: folder) else { return }
        var updatedFolder = folders[folderIndex]
        updatedFolder.apps.append(app)
        folders[folderIndex] = updatedFolder
        if let appIndex = apps.firstIndex(of: app) { apps.remove(at: appIndex) }
        if let pos = items.firstIndex(of: .app(app)) {
            items[pos] = .empty(UUID().uuidString)
            compactItemsWithinPages()
        } else {
            rebuildItems()
        }
        for idx in items.indices {
            if case .folder(let f) = items[idx], f.id == updatedFolder.id {
                items[idx] = .folder(updatedFolder)
            }
        }
        triggerFolderUpdate()
        triggerGridRefresh()
        refreshCacheAfterFolderOperation()
        saveAllOrder()
    }
    
    func removeAppFromFolder(_ app: AppInfo, folder: FolderInfo) {
        guard let folderIndex = folders.firstIndex(of: folder) else { return }
        var updatedFolder = folders[folderIndex]
        updatedFolder.apps.removeAll { $0 == app }
        if updatedFolder.apps.isEmpty {
            folders.remove(at: folderIndex)
        } else {
            folders[folderIndex] = updatedFolder
        }
        for idx in items.indices {
            if case .folder(let f) = items[idx], f.id == folder.id {
                if updatedFolder.apps.isEmpty {
                    items[idx] = .empty(UUID().uuidString)
                } else {
                    items[idx] = .folder(updatedFolder)
                }
            }
        }
        apps.append(app)
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if let emptyIndex = items.firstIndex(where: { if case .empty = $0 { return true } else { return false } }) {
            items[emptyIndex] = .app(app)
        }
        triggerFolderUpdate()
        triggerGridRefresh()
        compactItemsWithinPages()
        refreshCacheAfterFolderOperation()
        saveAllOrder()
    }
    
    func renameFolder(_ folder: FolderInfo, newName: String) {
        guard let index = folders.firstIndex(of: folder) else { return }
        var updatedFolder = folders[index]
        updatedFolder.name = newName
        folders[index] = updatedFolder
        for idx in items.indices {
            if case .folder(let f) = items[idx], f.id == updatedFolder.id {
                items[idx] = .folder(updatedFolder)
            }
        }
        triggerFolderUpdate()
        triggerGridRefresh()
        refreshCacheAfterFolderOperation()
        rebuildItems()
        saveAllOrder()
    }

    func presentRenameFolderPanel(for folder: FolderInfo) {
        let alert = NSAlert()
        alert.messageText = LocalizationManager.shared.text(.renameApp)
        alert.informativeText = LocalizationManager.shared.text(.renameFolderDescription)
        alert.addButton(withTitle: LocalizationManager.shared.text(.save))
        alert.addButton(withTitle: LocalizationManager.shared.text(.cancel))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        textField.stringValue = folder.name
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty else {
                NSSound.beep()
                return
            }
            renameFolder(folder, newName: newName)
        }
    }

    func removeFolder(_ folder: FolderInfo) {
        folders.removeAll { $0.id == folder.id }
        items = items.map { item in
            if case .folder(let existingFolder) = item, existingFolder.id == folder.id {
                return .empty(UUID().uuidString)
            }
            return item
        }
        if openFolder?.id == folder.id {
            openFolder = nil
        }
        compactItemsWithinPages()
        rebuildItems()
        saveAllOrder()
        triggerFolderUpdate()
        triggerGridRefresh()
        refreshCacheAfterFolderOperation()
    }
    
    func resetLayout() {
        openFolder = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [AppInfo] = []
            var seenPaths = Set<String>()
            for path in self.applicationSearchPaths {
                let url = URL(fileURLWithPath: path)
                if let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    for case let item as URL in enumerator {
                        let resolved = item.resolvingSymlinksInPath()
                        guard resolved.pathExtension == "app",
                              self.isValidApp(at: resolved),
                              !self.isInsideAnotherApp(resolved) else { continue }
                        if !seenPaths.contains(resolved.path) {
                            seenPaths.insert(resolved.path)
                            found.append(self.appInfo(from: resolved))
                        }
                    }
                }
            }
            var unique: [AppInfo] = []
            var seen = Set<String>()
            for a in found {
                if !seen.contains(a.url.path) {
                    seen.insert(a.url.path)
                    unique.append(a)
                }
            }
            let sorted = unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.availableApps = sorted
                self.processScannedApplicationsForPersistedLayout(sorted)
                self.refreshCacheAfterFolderOperation()
                self.triggerFolderUpdate()
                self.triggerGridRefresh()
            }
        }
    }
    
    /// 单页内自动补位
    func compactItemsWithinPages() {
        guard !items.isEmpty else { return }
        let ipp = self.itemsPerPage
        var result: [LaunchpadItem] = []
        result.reserveCapacity(items.count)
        var index = 0
        while index < items.count {
            let end = min(index + ipp, items.count)
            let pageSlice = Array(items[index..<end])
            let nonEmpty = pageSlice.filter { if case .empty = $0 { return false } else { return true } }
            let emptyCount = pageSlice.count - nonEmpty.count
            result.append(contentsOf: nonEmpty)
            if emptyCount > 0 {
                var empties: [LaunchpadItem] = []
                empties.reserveCapacity(emptyCount)
                for _ in 0..<emptyCount { empties.append(.empty(UUID().uuidString)) }
                result.append(contentsOf: empties)
            }
            index = end
        }
        items = result
    }

    // MARK: - 跨页拖拽
    func moveItemAcrossPagesWithCascade(item: LaunchpadItem, to targetIndex: Int) {
        guard items.indices.contains(targetIndex) || targetIndex == items.count else { return }
        guard let source = items.firstIndex(of: item) else { return }
        var result = items
        result[source] = .empty(UUID().uuidString)
        result = cascadeInsert(into: result, item: item, at: targetIndex)
        items = result
        let ipp = itemsPerPage
        let targetPage = targetIndex / ipp
        let currentPages = (items.count + ipp - 1) / ipp
        if targetPage == currentPages - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.compactItemsWithinPages()
                self.triggerGridRefresh()
            }
        } else {
            compactItemsWithinPages()
        }
        triggerGridRefresh()
        saveAllOrder()
    }

    private func cascadeInsert(into array: [LaunchpadItem], item: LaunchpadItem, at targetIndex: Int) -> [LaunchpadItem] {
        var result = array
        let p = self.itemsPerPage
        if result.count % p != 0 {
            let remain = p - (result.count % p)
            for _ in 0..<remain { result.append(.empty(UUID().uuidString)) }
        }
        var currentPage = max(0, targetIndex / p)
        var localIndex = max(0, min(targetIndex - currentPage * p, p - 1))
        var carry: LaunchpadItem? = item
        while let moving = carry {
            let pageStart = currentPage * p
            let pageEnd = pageStart + p
            if result.count < pageEnd {
                let need = pageEnd - result.count
                for _ in 0..<need { result.append(.empty(UUID().uuidString)) }
            }
            var slice = Array(result[pageStart..<pageEnd])
            let safeLocalIndex = max(0, min(localIndex, slice.count))
            slice.insert(moving, at: safeLocalIndex)
            var spilled: LaunchpadItem? = nil
            if slice.count > p { spilled = slice.removeLast() }
            result.replaceSubrange(pageStart..<pageEnd, with: slice)
            if let s = spilled, case .empty = s { carry = nil }
            else if let s = spilled {
                carry = s
                currentPage += 1
                localIndex = 0
                let nextEnd = (currentPage + 1) * p
                if result.count < nextEnd {
                    let need = nextEnd - result.count
                    for _ in 0..<need { result.append(.empty(UUID().uuidString)) }
                }
            } else { carry = nil }
        }
        return result
    }
    
    func rebuildItems() {
        let currentItemsCount = items.count
        let appsInFolders: Set<AppInfo> = Set(folders.flatMap { $0.apps })
        let folderById: [String: FolderInfo] = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        var newItems: [LaunchpadItem] = []
        newItems.reserveCapacity(currentItemsCount + 10)
        var seenAppPaths = Set<String>()
        var seenFolderIds = Set<String>()
        seenAppPaths.reserveCapacity(apps.count)
        seenFolderIds.reserveCapacity(folders.count)

        for item in items {
            switch item {
            case .folder(let folder):
                if let updated = folderById[folder.id] {
                    newItems.append(.folder(updated))
                    seenFolderIds.insert(updated.id)
                }
            case .app(let app):
                if !appsInFolders.contains(app) {
                    newItems.append(.app(app))
                    seenAppPaths.insert(app.url.path)
                }
            case .empty(let token):
                newItems.append(.empty(token))
            }
        }
        let missingFreeApps = apps.filter { !appsInFolders.contains($0) && !seenAppPaths.contains($0.url.path) }
        newItems.append(contentsOf: missingFreeApps.map { .app($0) })
        if newItems.count != items.count || !newItems.elementsEqual(items, by: { $0.id == $1.id }) {
            items = newItems
        }
    }
    
    // MARK: - Persistence
    func loadAllOrder() {
        guard let modelContext else {
            print("LaunchNow: ModelContext is nil, cannot load persisted order")
            return
        }
        print("LaunchNow: Attempting to load persisted order data...")
        if loadOrderFromPageEntries(using: modelContext) {
            print("LaunchNow: Successfully loaded order from PageEntryData")
            return
        }
        print("LaunchNow: PageEntryData not found, trying legacy TopItemData...")
        loadOrderFromLegacyTopItems(using: modelContext)
        print("LaunchNow: Finished loading order from legacy data")
    }

    private func loadOrderFromPageEntries(using modelContext: ModelContext) -> Bool {
        do {
            let descriptor = FetchDescriptor<PageEntryData>(
                sortBy: [SortDescriptor(\.pageIndex, order: .forward), SortDescriptor(\.position, order: .forward)]
            )
            let saved = try modelContext.fetch(descriptor)
            guard !saved.isEmpty else { return false }

            var folderMap: [String: FolderInfo] = [:]
            var foldersInOrder: [FolderInfo] = []
            for row in saved where row.kind == "folder" {
                guard let fid = row.folderId else { continue }
                if folderMap[fid] != nil { continue }
                let folderApps: [AppInfo] = row.appPaths.compactMap { path in
                    if let existing = apps.first(where: { $0.url.path == path }) {
                        return existing
                    }
                    let url = URL(fileURLWithPath: path)
                    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                    return self.appInfo(from: url)
                }
                let folder = FolderInfo(id: fid, name: row.folderName ?? LocalizationManager.shared.text(.untitledFolder), apps: folderApps, createdAt: row.createdAt)
                folderMap[fid] = folder
                foldersInOrder.append(folder)
            }

            let folderAppPathSet: Set<String> = Set(foldersInOrder.flatMap { $0.apps.map { $0.url.path } })
            var combined: [LaunchpadItem] = []
            combined.reserveCapacity(saved.count)
            for row in saved {
                switch row.kind {
                case "folder":
                    if let fid = row.folderId, let folder = folderMap[fid] {
                        combined.append(.folder(folder))
                    }
                case "app":
                    if let path = row.appPath, !folderAppPathSet.contains(path) {
                        if let existing = apps.first(where: { $0.url.path == path }) {
                            combined.append(.app(existing))
                        } else {
                            let url = URL(fileURLWithPath: path)
                            if FileManager.default.fileExists(atPath: url.path) {
                                combined.append(.app(self.appInfo(from: url)))
                            }
                        }
                    }
                case "empty":
                    combined.append(.empty(row.slotId))
                default:
                    break
                }
            }

            DispatchQueue.main.async {
                self.folders = foldersInOrder
                if !combined.isEmpty {
                    self.items = combined
                    if self.apps.isEmpty {
                        let freeApps: [AppInfo] = combined.compactMap { if case let .app(a) = $0 { return a } else { return nil } }
                        self.apps = freeApps
                    }
                }
                self.hasAppliedOrderFromStore = true
            }
            return true
        } catch {
            return false
        }
    }

    private func loadOrderFromLegacyTopItems(using modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<TopItemData>(sortBy: [SortDescriptor(\.orderIndex, order: .forward)])
            let saved = try modelContext.fetch(descriptor)
            guard !saved.isEmpty else { return }

            var folderMap: [String: FolderInfo] = [:]
            var foldersInOrder: [FolderInfo] = []
            let folderAppPathSet: Set<String> = Set(saved.filter { $0.kind == "folder" }.flatMap { $0.appPaths })
            for row in saved where row.kind == "folder" {
                let folderApps: [AppInfo] = row.appPaths.compactMap { path in
                    if let existing = apps.first(where: { $0.url.path == path }) { return existing }
                    let url = URL(fileURLWithPath: path)
                    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                    return self.appInfo(from: url)
                }
                let folder = FolderInfo(id: row.id, name: row.folderName ?? LocalizationManager.shared.text(.untitledFolder), apps: folderApps, createdAt: row.createdAt)
                folderMap[row.id] = folder
                foldersInOrder.append(folder)
            }

            var combined: [LaunchpadItem] = saved.sorted { $0.orderIndex < $1.orderIndex }.compactMap { row in
                if row.kind == "folder" { return folderMap[row.id].map { .folder($0) } }
                if row.kind == "empty" { return .empty(row.id) }
                if row.kind == "app", let path = row.appPath {
                    if folderAppPathSet.contains(path) { return nil }
                    if let existing = apps.first(where: { $0.url.path == path }) { return .app(existing) }
                    let url = URL(fileURLWithPath: path)
                    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                    return .app(self.appInfo(from: url))
                }
                return nil
            }

            let appsInFolders = Set(foldersInOrder.flatMap { $0.apps })
            let appsInCombined: Set<AppInfo> = Set(combined.compactMap { if case let .app(a) = $0 { return a } else { return nil } })
            let missingFreeApps = apps
                .filter { !appsInFolders.contains($0) && !appsInCombined.contains($0) }
                .map { LaunchpadItem.app($0) }
            combined.append(contentsOf: missingFreeApps)

            DispatchQueue.main.async {
                self.folders = foldersInOrder
                if !combined.isEmpty {
                    self.items = combined
                    if self.apps.isEmpty {
                        let freeAppsAfterLoad: [AppInfo] = combined.compactMap { if case let .app(a) = $0 { return a } else { return nil } }
                        self.apps = freeAppsAfterLoad
                    }
                }
                self.hasAppliedOrderFromStore = true
            }
        } catch {
            // ignore
        }
    }

    func saveAllOrder() {
        guard let modelContext else {
            print("LaunchNow: ModelContext is nil, cannot save order")
            return
        }
        guard !items.isEmpty else {
            print("LaunchNow: Items list is empty, skipping save")
            return
        }
        print("LaunchNow: Saving order data for \(items.count) items...")
        do {
            let existing = try modelContext.fetch(FetchDescriptor<PageEntryData>())
            print("LaunchNow: Found \(existing.count) existing entries, clearing...")
            for row in existing { modelContext.delete(row) }
            let folderById: [String: FolderInfo] = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
            let ipp = self.itemsPerPage
            for (idx, item) in items.enumerated() {
                let pageIndex = idx / ipp
                let position = idx % ipp
                let slotId = "page-\(pageIndex)-pos-\(position)"
                switch item {
                case .folder(let folder):
                    let authoritativeFolder = folderById[folder.id] ?? folder
                    let row = PageEntryData(
                        slotId: slotId,
                        pageIndex: pageIndex,
                        position: position,
                        kind: "folder",
                        folderId: authoritativeFolder.id,
                        folderName: authoritativeFolder.name,
                        appPaths: authoritativeFolder.apps.map { $0.url.path }
                    )
                    modelContext.insert(row)
                case .app(let app):
                    let row = PageEntryData(
                        slotId: slotId,
                        pageIndex: pageIndex,
                        position: position,
                        kind: "app",
                        appPath: app.url.path
                    )
                    modelContext.insert(row)
                case .empty:
                    let row = PageEntryData(
                        slotId: slotId,
                        pageIndex: pageIndex,
                        position: position,
                        kind: "empty"
                    )
                    modelContext.insert(row)
                }
            }
            try modelContext.save()
            print("LaunchNow: Successfully saved order data")
            do {
                let legacy = try modelContext.fetch(FetchDescriptor<TopItemData>())
                for row in legacy { modelContext.delete(row) }
                try? modelContext.save()
            } catch { }
        } catch {
            print("LaunchNow: Error saving order data: \(error)")
        }
    }

    private func triggerFolderUpdate() { folderUpdateTrigger = UUID() }
    func triggerGridRefresh() { gridRefreshTrigger = UUID() }
    
    private func clearAllPersistedData() {
        guard let modelContext else { return }
        do {
            let pageEntries = try modelContext.fetch(FetchDescriptor<PageEntryData>())
            for entry in pageEntries { modelContext.delete(entry) }
            let legacyEntries = try modelContext.fetch(FetchDescriptor<TopItemData>())
            for entry in legacyEntries { modelContext.delete(entry) }
            try modelContext.save()
        } catch { }
    }

    // MARK: - 拖拽时自动创建新页
    private var pendingNewPage: (pageIndex: Int, itemCount: Int)? = nil
    
    func createNewPageForDrag() -> Bool {
        let ipp = self.itemsPerPage
        let currentPages = (items.count + ipp - 1) / ipp
        let newPageIndex = currentPages
        for _ in 0..<ipp { items.append(.empty(UUID().uuidString)) }
        pendingNewPage = (pageIndex: newPageIndex, itemCount: ipp)
        triggerGridRefresh()
        return true
    }
    
    func cleanupUnusedNewPage() {
        guard let pending = pendingNewPage else { return }
        let pageStart = pending.pageIndex * pending.itemCount
        let pageEnd = min(pageStart + pending.itemCount, items.count)
        if pageStart < items.count {
            let pageSlice = Array(items[pageStart..<pageEnd])
            let hasNonEmptyItems = pageSlice.contains { item in
                if case .empty = item { return false } else { return true }
            }
            if !hasNonEmptyItems {
                items.removeSubrange(pageStart..<pageEnd)
                triggerGridRefresh()
            }
        }
        pendingNewPage = nil
    }

    // MARK: - 自动删除空白页面
    func removeEmptyPages() {
        guard !items.isEmpty else { return }
        let ipp = self.itemsPerPage
        var newItems: [LaunchpadItem] = []
        var index = 0
        while index < items.count {
            let end = min(index + ipp, items.count)
            let pageSlice = Array(items[index..<end])
            let isEmptyPage = pageSlice.allSatisfy { item in
                if case .empty = item { return true } else { return false }
            }
            if !isEmptyPage { newItems.append(contentsOf: pageSlice) }
            index = end
        }
        if newItems.count != items.count {
            items = newItems
            let maxPageIndex = max(0, (items.count - 1) / ipp)
            if currentPage > maxPageIndex { currentPage = maxPageIndex }
            triggerGridRefresh()
        }
    }
    
    // MARK: - 导出/导入布局 JSON (unchanged)
    func exportAppOrderAsJSON() -> String? {
        let exportData = buildExportData()
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
            return String(data: jsonData, encoding: .utf8)
        } catch { return nil }
    }
    
    private func buildExportData() -> [String: Any] {
        var pages: [[String: Any]] = []
        let ipp = self.itemsPerPage
        for (index, item) in items.enumerated() {
            let pageIndex = index / ipp
            let position = index % ipp
            var itemData: [String: Any] = [
                "pageIndex": pageIndex,
                "position": position,
                "kind": itemKind(for: item),
                "name": item.name,
                "path": itemPath(for: item),
                "folderApps": []
            ]
            if case let .folder(folder) = item {
                itemData["folderApps"] = folder.apps.map { $0.name }
                itemData["folderAppPaths"] = folder.apps.map { $0.url.path }
            }
            pages.append(itemData)
        }
        return [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "totalPages": (items.count + ipp - 1) / ipp,
            "totalItems": items.count,
            "fullscreenMode": isFullscreenMode,
            "gridColumns": gridColumns,
            "gridRows": gridRows,
            "pages": pages
        ]
    }
    
    private func itemKind(for item: LaunchpadItem) -> String {
        switch item {
        case .app: return "应用"
        case .folder: return "文件夹"
        case .empty: return "空槽位"
        }
    }
    private func itemPath(for item: LaunchpadItem) -> String {
        switch item {
        case let .app(app): return app.url.path
        case let .folder(folder): return "文件夹: \(folder.name)"
        case .empty: return "空槽位"
        }
    }
    
    func saveExportFileWithDialog(content: String, filename: String, fileExtension: String, fileType: String) -> Bool {
        let savePanel = NSSavePanel()
        savePanel.title = "保存导出文件"
        savePanel.nameFieldStringValue = filename
        savePanel.allowedContentTypes = [UTType(filenameExtension: fileExtension) ?? .plainText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            savePanel.directoryURL = desktopURL
        }
        let response = AppPanelPresenter.runModal(savePanel)
        if response == .OK, let url = savePanel.url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                return true
            } catch { return false }
        }
        return false
    }
    
    // MARK: - 缓存管理
    private func generateCacheAfterScan() {
        if !cacheManager.isCacheValid {
            cacheManager.generateCache(from: availableApps, items: items)
        } else {
            cacheManager.smartPreloadIcons(
                for: items,
                currentPage: currentPage,
                itemsPerPage: itemsPerPage
            )
        }
    }
    
    func refresh() {
        print("LaunchNow: Manual refresh triggered")
        cacheManager.clearAllCaches()
        openFolder = nil
        currentPage = 0
        if !searchText.isEmpty { searchText = "" }
        hasPerformedInitialScan = true
        scanAvailableApplicationsOnly()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.generateCacheAfterScan()
        }
        triggerFolderUpdate()
        triggerGridRefresh()
    }
    
    func clearCache() { cacheManager.clearAllCaches() }
    var cacheStatistics: CacheStatistics { cacheManager.cacheStatistics }
    private func updateCacheAfterChanges() {
        if !cacheManager.isCacheValid {
            cacheManager.generateCache(from: availableApps, items: items)
        } else {
            cacheManager.smartPreloadIcons(
                for: items,
                currentPage: currentPage,
                itemsPerPage: itemsPerPage
            )
        }
    }
    private func refreshCacheAfterFolderOperation() {
        cacheManager.refreshCache(from: apps, items: items)
        if !searchText.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.searchText = "" }
        }
    }
    
    // MARK: - 导入应用排序 JSON (unchanged behavior)
    func importAppOrderFromJSON(_ jsonData: Data) -> Bool {
        do {
            let importData = try JSONSerialization.jsonObject(with: jsonData, options: [])
            return processImportedData(importData)
        } catch { return false }
    }
    
    private func processImportedData(_ importData: Any) -> Bool {
        guard let data = importData as? [String: Any],
              let pagesData = data["pages"] as? [[String: Any]] else {
            return false
        }
        let appPathMap = Dictionary(uniqueKeysWithValues: apps.map { ($0.url.path, $0) })
        var newItems: [LaunchpadItem] = []
        var importedFolders: [FolderInfo] = []
        for pageData in pagesData {
            guard let kind = pageData["kind"] as? String,
                  let name = pageData["name"] as? String else { continue }
            switch kind {
            case "应用":
                if let path = pageData["path"] as? String,
                   let app = appPathMap[path] {
                    newItems.append(.app(app))
                } else {
                    newItems.append(.empty(UUID().uuidString))
                }
            case "文件夹":
                if let folderApps = pageData["folderApps"] as? [String],
                   let folderAppPaths = pageData["folderAppPaths"] as? [String] {
                    let folderAppsList = folderAppPaths.compactMap { appPath in
                        if let app = apps.first(where: { $0.url.path == appPath }) {
                            return app
                        }
                        if let appName = folderApps.first(where: { _ in true }),
                           let app = apps.first(where: { $0.name == appName }) {
                            return app
                        }
                        return nil
                    }
                    if !folderAppsList.isEmpty {
                        let existingFolder = self.folders.first { existingFolder in
                            existingFolder.name == name &&
                            existingFolder.apps.count == folderAppsList.count &&
                            existingFolder.apps.allSatisfy { app in
                                folderAppsList.contains { $0.id == app.id }
                            }
                        }
                        if let existing = existingFolder {
                            importedFolders.append(existing)
                            newItems.append(.folder(existing))
                        } else {
                            let folder = FolderInfo(name: name, apps: folderAppsList)
                            importedFolders.append(folder)
                            newItems.append(.folder(folder))
                        }
                    } else {
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else if let folderApps = pageData["folderApps"] as? [String] {
                    let folderAppsList = folderApps.compactMap { appName in
                        apps.first { $0.name == appName }
                    }
                    if !folderAppsList.isEmpty {
                        let existingFolder = self.folders.first { existingFolder in
                            existingFolder.name == name &&
                            existingFolder.apps.count == folderAppsList.count &&
                            existingFolder.apps.allSatisfy { app in
                                folderAppsList.contains { $0.id == app.id }
                            }
                        }
                        if let existing = existingFolder {
                            importedFolders.append(existing)
                            newItems.append(.folder(existing))
                        } else {
                            let folder = FolderInfo(name: name, apps: folderAppsList)
                            importedFolders.append(folder)
                            newItems.append(.folder(folder))
                        }
                    } else {
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else {
                    newItems.append(.empty(UUID().uuidString))
                }
            case "空槽位":
                newItems.append(.empty(UUID().uuidString))
            default:
                newItems.append(.empty(UUID().uuidString))
            }
        }
        let usedApps = Set(newItems.compactMap { item in
            if case let .app(app) = item { return app }
            return nil
        })
        let usedAppsInFolders = Set(importedFolders.flatMap { $0.apps })
        let allUsedApps = usedApps.union(usedAppsInFolders)
        let unusedApps = apps.filter { !allUsedApps.contains($0) }
        if !unusedApps.isEmpty {
            let ipp = self.itemsPerPage
            let currentPages = (newItems.count + ipp - 1) / ipp
            let lastPageStart = currentPages * ipp
            let lastPageEnd = lastPageStart + ipp
            while newItems.count < lastPageEnd { newItems.append(.empty(UUID().uuidString)) }
            for (index, app) in unusedApps.enumerated() {
                let insertIndex = lastPageStart + index
                if insertIndex < newItems.count {
                    newItems[insertIndex] = .app(app)
                } else {
                    newItems.append(.app(app))
                }
            }
            let finalPageCount = newItems.count
            let finalPages = (finalPageCount + ipp - 1) / ipp
            let finalLastPageStart = (finalPages - 1) * ipp
            let finalLastPageEnd = finalLastPageStart + ipp
            while newItems.count < finalLastPageEnd { newItems.append(.empty(UUID().uuidString)) }
        }
        DispatchQueue.main.async {
            self.folders = importedFolders
            self.items = newItems
            self.triggerFolderUpdate()
            self.triggerGridRefresh()
            self.saveAllOrder()
        }
        return true
    }
    
    func validateImportData(_ jsonData: Data) -> (isValid: Bool, message: String) {
        do {
            let importData = try JSONSerialization.jsonObject(with: jsonData, options: [])
            guard let data = importData as? [String: Any] else {
                return (false, "数据格式无效")
            }
            guard let pagesData = data["pages"] as? [[String: Any]] else {
                return (false, "缺少页面数据")
            }
            let totalPages = data["totalPages"] as? Int ?? 0
            let totalItems = data["totalItems"] as? Int ?? 0
            if pagesData.isEmpty { return (false, "没有找到应用数据") }
            return (true, "数据验证通过，共\(totalPages)页，\(totalItems)个项目")
        } catch {
            return (false, "JSON解析失败: \(error.localizedDescription)")
        }
    }
}

private extension JSONEncoder {
    static var prettyProfileEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var profileDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
