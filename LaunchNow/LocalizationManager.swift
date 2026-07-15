import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case thai
    case japanese
    case korean
    case simplifiedChinese
    case spanish
    case french
    case german
    case portugueseBrazil
    case indonesian
    case vietnamese

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .system:
            return Locale.current.language.languageCode?.identifier ?? "en"
        case .english:
            return "en"
        case .thai:
            return "th"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        case .simplifiedChinese:
            return "zh-Hans"
        case .spanish:
            return "es"
        case .french:
            return "fr"
        case .german:
            return "de"
        case .portugueseBrazil:
            return "pt-BR"
        case .indonesian:
            return "id"
        case .vietnamese:
            return "vi"
        }
    }

    var displayNameKey: L10nKey {
        switch self {
        case .system: return .system
        case .english: return .english
        case .thai: return .thai
        case .japanese: return .japanese
        case .korean: return .korean
        case .simplifiedChinese: return .simplifiedChinese
        case .spanish: return .spanish
        case .french: return .french
        case .german: return .german
        case .portugueseBrazil: return .portugueseBrazil
        case .indonesian: return .indonesian
        case .vietnamese: return .vietnamese
        }
    }
}

enum L10nKey: String {
    case general
    case appearance
    case gridLayout
    case appManagement
    case appSources
    case data
    case about
    case refresh
    case resetLayout
    case quit
    case language
    case keyboardShortcut
    case keyboardShortcutDescription
    case shortcutDisabled
    case shortcutOptionSpace
    case shortcutControlSpace
    case shortcutCommandShiftSpace
    case shortcutControlOptionSpace
    case shortcutCommandOptionL
    case english
    case thai
    case japanese
    case korean
    case simplifiedChinese
    case spanish
    case french
    case german
    case portugueseBrazil
    case indonesian
    case vietnamese
    case system
    case runInBackground
    case runInBackgroundDescription
    case searchScope
    case searchScopeDescription
    case searchLaunchNowApps
    case searchAllApplications
    case classicLaunchpad
    case fullscreenLayout
    case scrollingSensitivity
    case appearancePreset
    case appearanceGlass
    case appearanceDark
    case appearanceLight
    case appearanceCompact
    case appearanceClassicLaunchpad
    case background
    case backgroundPreset
    case backgroundOpacity
    case backgroundBlur
    case backgroundSystem
    case backgroundAurora
    case backgroundGraphite
    case backgroundSunset
    case backgroundForest
    case backgroundCustomImage
    case chooseBackgroundImage
    case resetBackgroundImage
    case low
    case high
    case columns
    case rows
    case appColumnsDescription
    case appRowsDescription
    case itemsPerPage
    case addApp
    case resetApp
    case autoOrganizeApps
    case autoOrganizeAppsDescription
    case confirmAutoOrganize
    case confirmAutoOrganizeMessage
    case organize
    case open
    case showInFinder
    case renameApp
    case resetName
    case save
    case renameAppDescription
    case renameFolderDescription
    case changeIcon
    case resetIcon
    case chooseCustomIcon
    case folders
    case chooseCustomFolderIcon
    case noFoldersInLaunchpad
    case removeAppsDescription
    case searchApps
    case remove
    case noAppsInLaunchpad
    case noResults
    case manageAppLibraries
    case appLibrariesDescription
    case systemDirectories
    case customDirectories
    case noCustomDirectories
    case addFolders
    case restoreDefaults
    case exportData
    case importData
    case exportImportDescription
    case profiles
    case profileName
    case saveCurrentProfile
    case renameProfile
    case applyProfile
    case deleteProfile
    case noProfiles
    case profilesDescription
    case updatedFormat
    case cloudBackup
    case cloudBackupDescription
    case chooseCloudFolder
    case changeCloudFolder
    case clearCloudFolder
    case backupNow
    case restoreFromCloud
    case noCloudFolder
    case lastCloudBackupFormat
    case chooseCloudBackupFolder
    case cloudBackupComplete
    case cloudBackupFailed
    case cloudRestoreComplete
    case cloudRestoreFailed
    case versionFormat
    case aboutDescription
    case autoCheckUpdates
    case autoCheckUpdatesDescription
    case lastAutoUpdateCheckFormat
    case automaticUpdateAvailableFormat
    case automaticUpdateCheckFailed
    case checkForUpdates
    case checkingForUpdates
    case appUpToDate
    case updateAvailableFormat
    case updateCheckFailed
    case downloadUpdate
    case installUpdate
    case downloadingUpdate
    case installingUpdate
    case installingUpdateRelaunch
    case updateDownloadedFormat
    case updateDownloadFailed
    case updateInstallFailed
    case updateNotificationTitleFormat
    case updateNotificationBody
    case uninstall
    case uninstallDescription
    case uninstallTitle
    case uninstallWarning
    case alsoRemoveData
    case cancel
    case clear
    case reset
    case confirmResetLayout
    case confirmResetLayoutMessage
    case confirmClearApps
    case confirmClearAppsMessage
    case removeThisFolder
    case choose
    case add
    case `import`
    case chooseFoldersContainingApps
    case chooseExportDestination
    case chooseImportFolder
    case selectAppsToAdd
    case selectAll
    case selectAppsToRemove
    case includeFolderApps
    case search
    case noAppsFound
    case folderName
    case untitledFolder
    case categoryDeveloper
    case categoryDesign
    case categoryGames
    case categoryUtilities
    case categoryProductivity
    case categoryEducation
    case categoryEntertainment
    case categoryMusic
    case categoryPhotoVideo
    case categorySocial
    case categoryFinance
    case categoryHealth
    case categoryLifestyle
    case categoryReference
    case categoryOther
}

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    private static let languageDefaultsKey = "appLanguage"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageDefaultsKey)
        }
    }

    private init() {
        let rawValue = UserDefaults.standard.string(forKey: Self.languageDefaultsKey) ?? AppLanguage.system.rawValue
        language = AppLanguage(rawValue: rawValue) ?? .system
    }

    func text(_ key: L10nKey) -> String {
        let language = resolvedLanguage
        return Self.translations[language]?[key] ?? Self.translations[.english]?[key] ?? key.rawValue
    }

    func text(_ key: L10nKey, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: language.localeIdentifier), arguments: arguments)
    }

    private var resolvedLanguage: AppLanguage {
        switch language {
        case .system:
            switch Locale.current.language.languageCode?.identifier {
            case "th": return .thai
            case "ja": return .japanese
            case "ko": return .korean
            case "zh": return .simplifiedChinese
            case "es": return .spanish
            case "fr": return .french
            case "de": return .german
            case "pt": return .portugueseBrazil
            case "id": return .indonesian
            case "vi": return .vietnamese
            default: return .english
            }
        case .english, .thai, .japanese, .korean, .simplifiedChinese, .spanish, .french, .german, .portugueseBrazil, .indonesian, .vietnamese:
            return language
        }
    }

    private static let translations: [AppLanguage: [L10nKey: String]] = [
        .english: [
            .general: "General",
            .appearance: "Appearance",
            .gridLayout: "Grid Layout",
            .appManagement: "App Management",
            .appSources: "App Sources",
            .data: "Data",
            .about: "About",
            .refresh: "Refresh",
            .resetLayout: "Reset Layout",
            .quit: "Quit",
            .language: "Language",
            .keyboardShortcut: "Keyboard shortcut",
            .keyboardShortcutDescription: "Use this global shortcut to show or hide LaunchNow while it runs in the background.",
            .shortcutDisabled: "Disabled",
            .shortcutOptionSpace: "Option + Space",
            .shortcutControlSpace: "Control + Space",
            .shortcutCommandShiftSpace: "Command + Shift + Space",
            .shortcutControlOptionSpace: "Control + Option + Space",
            .shortcutCommandOptionL: "Command + Option + L",
            .english: "English",
            .thai: "Thai",
            .japanese: "Japanese",
            .korean: "Korean",
            .simplifiedChinese: "Chinese (Simplified)",
            .spanish: "Spanish",
            .french: "French",
            .german: "German",
            .portugueseBrazil: "Portuguese (Brazil)",
            .indonesian: "Indonesian",
            .vietnamese: "Vietnamese",
            .system: "System",
            .runInBackground: "Run in background",
            .runInBackgroundDescription: "Add LaunchNow to the Dock or use keyboard shortcuts to open the window quickly.",
            .searchScope: "Search scope",
            .searchScopeDescription: "Choose whether LaunchNow search includes only added apps or every app found on this Mac.",
            .searchLaunchNowApps: "LaunchNow Apps",
            .searchAllApplications: "All Applications",
            .classicLaunchpad: "Classic Launchpad (Fullscreen)",
            .fullscreenLayout: "Use fullscreen layout and spacing",
            .scrollingSensitivity: "Scrolling sensitivity",
            .appearancePreset: "Appearance preset",
            .appearanceGlass: "Glass",
            .appearanceDark: "Dark",
            .appearanceLight: "Light",
            .appearanceCompact: "Compact",
            .appearanceClassicLaunchpad: "Classic Launchpad",
            .background: "Background",
            .backgroundPreset: "Preset",
            .backgroundOpacity: "Opacity",
            .backgroundBlur: "Blur",
            .backgroundSystem: "System Glass",
            .backgroundAurora: "Aurora",
            .backgroundGraphite: "Graphite",
            .backgroundSunset: "Sunset",
            .backgroundForest: "Forest",
            .backgroundCustomImage: "Custom Image",
            .chooseBackgroundImage: "Choose an image to use as the LaunchNow background.",
            .resetBackgroundImage: "Reset Background Image",
            .low: "Low",
            .high: "High",
            .columns: "Columns",
            .rows: "Rows",
            .appColumnsDescription: "Number of app columns per page",
            .appRowsDescription: "Number of app rows per page",
            .itemsPerPage: "Items per page",
            .addApp: "Add App",
            .resetApp: "Reset App",
            .autoOrganizeApps: "Auto-organize Apps",
            .autoOrganizeAppsDescription: "Group the apps currently in LaunchNow into category folders.",
            .confirmAutoOrganize: "Auto-organize apps?",
            .confirmAutoOrganizeMessage: "This will rearrange your current LaunchNow layout into category folders. Your apps on disk are not affected.",
            .organize: "Organize",
            .open: "Open",
            .showInFinder: "Show in Finder",
            .renameApp: "Rename",
            .resetName: "Reset Name",
            .save: "Save",
            .renameAppDescription: "Set a custom display name for this app. The real app bundle is not renamed.",
            .renameFolderDescription: "Set a custom display name for this folder.",
            .changeIcon: "Change Icon",
            .resetIcon: "Reset Icon",
            .chooseCustomIcon: "Choose an image to use as this app icon.",
            .folders: "Folders",
            .chooseCustomFolderIcon: "Choose an image to use as this folder icon.",
            .noFoldersInLaunchpad: "No folders in Launchpad.",
            .removeAppsDescription: "Remove apps from Launchpad (does not delete apps from disk).",
            .searchApps: "Search apps",
            .remove: "Remove",
            .noAppsInLaunchpad: "No apps in Launchpad.",
            .noResults: "No results.",
            .manageAppLibraries: "Manage additional app libraries",
            .appLibrariesDescription: "Add external drives or custom folders so LaunchNow can gather apps beyond the default locations.",
            .systemDirectories: "System directories",
            .customDirectories: "Custom directories",
            .noCustomDirectories: "No custom directories yet. Add one to keep extra apps in sync.",
            .addFolders: "Add folders...",
            .restoreDefaults: "Restore defaults",
            .exportData: "Export Data",
            .importData: "Import Data",
            .exportImportDescription: "Export/Import includes your layout, folders and settings.",
            .profiles: "Profiles",
            .profileName: "Profile name",
            .saveCurrentProfile: "Save Current Profile",
            .renameProfile: "Rename Profile",
            .applyProfile: "Apply",
            .deleteProfile: "Delete",
            .noProfiles: "No profiles yet.",
            .profilesDescription: "Save multiple LaunchNow layouts and settings, then switch between them anytime.",
            .updatedFormat: "Updated %@",
            .cloudBackup: "Cloud Backup",
            .cloudBackupDescription: "Choose a synced folder such as iCloud Drive, Google Drive, Dropbox, or OneDrive to keep profile backups online.",
            .chooseCloudFolder: "Choose Folder",
            .changeCloudFolder: "Change Folder",
            .clearCloudFolder: "Clear Folder",
            .backupNow: "Backup Now",
            .restoreFromCloud: "Restore from Cloud",
            .noCloudFolder: "No cloud folder selected.",
            .lastCloudBackupFormat: "Last backup %@",
            .chooseCloudBackupFolder: "Choose a synced folder for LaunchNow backups",
            .cloudBackupComplete: "Cloud backup completed.",
            .cloudBackupFailed: "Could not backup profiles to the cloud folder.",
            .cloudRestoreComplete: "Profiles restored from the cloud folder.",
            .cloudRestoreFailed: "Could not restore profiles from the cloud folder.",
            .versionFormat: "Version %@",
            .aboutDescription: "A lightweight Launchpad-like app launcher.",
            .autoCheckUpdates: "Automatically check for updates",
            .autoCheckUpdatesDescription: "LaunchNow checks in the background and notifies you when a new release is available.",
            .lastAutoUpdateCheckFormat: "Last automatic check %@",
            .automaticUpdateAvailableFormat: "Version %@ is available from the automatic check.",
            .automaticUpdateCheckFailed: "The last automatic update check failed.",
            .checkForUpdates: "Check for Updates",
            .checkingForUpdates: "Checking for updates...",
            .appUpToDate: "LaunchNow is up to date.",
            .updateAvailableFormat: "Version %@ is available.",
            .updateCheckFailed: "Could not check for updates.",
            .downloadUpdate: "Download Update",
            .installUpdate: "Install Update",
            .downloadingUpdate: "Downloading update...",
            .installingUpdate: "Installing update...",
            .installingUpdateRelaunch: "Installing update. LaunchNow will quit and reopen automatically.",
            .updateDownloadedFormat: "Downloaded %@ and opened the installer.",
            .updateDownloadFailed: "Could not download the update.",
            .updateInstallFailed: "Could not install the update.",
            .updateNotificationTitleFormat: "LaunchNow %@ is available",
            .updateNotificationBody: "Open LaunchNow Settings to install the update.",
            .uninstall: "Uninstall",
            .uninstallDescription: "Quit the app and move it to the Trash. You can also remove app data.",
            .uninstallTitle: "Uninstall LaunchNow",
            .uninstallWarning: "The app will quit and attempt to move itself to the Trash. You can also remove its data (Application Support and preferences).",
            .alsoRemoveData: "Also remove app data (Application Support and preferences)",
            .cancel: "Cancel",
            .clear: "Clear",
            .reset: "Reset",
            .confirmResetLayout: "Confirm to reset layout?",
            .confirmResetLayoutMessage: "This will reset layout and rescan available apps. It won’t auto-add apps to Launchpad.",
            .confirmClearApps: "Clear all apps from Launchpad?",
            .confirmClearAppsMessage: "This will remove all apps, folders and layout from Launchpad. Your applications on disk are not affected.",
            .removeThisFolder: "Remove this folder",
            .choose: "Choose",
            .add: "Add",
            .import: "Import",
            .chooseFoldersContainingApps: "Choose folders that contain apps.",
            .chooseExportDestination: "Choose a destination folder to export LaunchNow data",
            .chooseImportFolder: "Choose a folder previously exported from LaunchNow",
            .selectAppsToAdd: "Select applications to add to Launchpad",
            .selectAll: "Select All",
            .selectAppsToRemove: "Select applications to remove from Launchpad",
            .includeFolderApps: "Include apps inside folders",
            .search: "Search",
            .noAppsFound: "No apps found",
            .folderName: "Folder Name",
            .untitledFolder: "Untitled",
            .categoryDeveloper: "Developer",
            .categoryDesign: "Design",
            .categoryGames: "Games",
            .categoryUtilities: "Utilities",
            .categoryProductivity: "Productivity",
            .categoryEducation: "Education",
            .categoryEntertainment: "Entertainment",
            .categoryMusic: "Music",
            .categoryPhotoVideo: "Photo & Video",
            .categorySocial: "Social",
            .categoryFinance: "Finance",
            .categoryHealth: "Health",
            .categoryLifestyle: "Lifestyle",
            .categoryReference: "Reference",
            .categoryOther: "Other"
        ],
        .thai: [
            .general: "ทั่วไป",
            .appearance: "การแสดงผล",
            .gridLayout: "การจัดวางกริด",
            .appManagement: "จัดการแอป",
            .appSources: "แหล่งแอป",
            .data: "ข้อมูล",
            .about: "เกี่ยวกับ",
            .refresh: "รีเฟรช",
            .resetLayout: "รีเซ็ตเลย์เอาต์",
            .quit: "ออก",
            .language: "ภาษา",
            .keyboardShortcut: "คีย์ลัด",
            .keyboardShortcutDescription: "ใช้คีย์ลัดนี้เพื่อแสดงหรือซ่อน LaunchNow ระหว่างที่แอปทำงานเบื้องหลัง",
            .shortcutDisabled: "ปิดใช้งาน",
            .shortcutOptionSpace: "Option + Space",
            .shortcutControlSpace: "Control + Space",
            .shortcutCommandShiftSpace: "Command + Shift + Space",
            .shortcutControlOptionSpace: "Control + Option + Space",
            .shortcutCommandOptionL: "Command + Option + L",
            .english: "อังกฤษ",
            .thai: "ไทย",
            .japanese: "ญี่ปุ่น",
            .korean: "เกาหลี",
            .simplifiedChinese: "จีนตัวย่อ",
            .spanish: "สเปน",
            .french: "ฝรั่งเศส",
            .german: "เยอรมัน",
            .portugueseBrazil: "โปรตุเกส (บราซิล)",
            .indonesian: "อินโดนีเซีย",
            .vietnamese: "เวียดนาม",
            .system: "ตามระบบ",
            .runInBackground: "ทำงานเบื้องหลัง",
            .runInBackgroundDescription: "เพิ่ม LaunchNow ไว้ใน Dock หรือใช้คีย์ลัดเพื่อเปิดหน้าต่างได้รวดเร็ว",
            .searchScope: "ขอบเขตการค้นหา",
            .searchScopeDescription: "เลือกว่าจะค้นหาเฉพาะแอปที่เพิ่มใน LaunchNow หรือค้นหาแอปทั้งหมดที่พบในเครื่องนี้",
            .searchLaunchNowApps: "แอปใน LaunchNow",
            .searchAllApplications: "แอปทั้งหมด",
            .classicLaunchpad: "Launchpad แบบคลาสสิก (เต็มหน้าจอ)",
            .fullscreenLayout: "ใช้เลย์เอาต์และระยะห่างแบบเต็มหน้าจอ",
            .scrollingSensitivity: "ความไวในการเลื่อน",
            .appearancePreset: "รูปแบบหน้าตา",
            .appearanceGlass: "Glass",
            .appearanceDark: "Dark",
            .appearanceLight: "Light",
            .appearanceCompact: "Compact",
            .appearanceClassicLaunchpad: "Classic Launchpad",
            .background: "พื้นหลัง",
            .backgroundPreset: "รูปแบบ",
            .backgroundOpacity: "ความทึบ",
            .backgroundBlur: "เบลอ",
            .backgroundSystem: "กระจกระบบ",
            .backgroundAurora: "Aurora",
            .backgroundGraphite: "Graphite",
            .backgroundSunset: "Sunset",
            .backgroundForest: "Forest",
            .backgroundCustomImage: "รูปภาพกำหนดเอง",
            .chooseBackgroundImage: "เลือกรูปภาพเพื่อใช้เป็นพื้นหลัง LaunchNow",
            .resetBackgroundImage: "รีเซ็ตรูปพื้นหลัง",
            .low: "ต่ำ",
            .high: "สูง",
            .columns: "คอลัมน์",
            .rows: "แถว",
            .appColumnsDescription: "จำนวนคอลัมน์ของแอปต่อหน้า",
            .appRowsDescription: "จำนวนแถวของแอปต่อหน้า",
            .itemsPerPage: "รายการต่อหน้า",
            .addApp: "เพิ่มแอป",
            .resetApp: "รีเซ็ตแอป",
            .autoOrganizeApps: "จัดกลุ่มแอปอัตโนมัติ",
            .autoOrganizeAppsDescription: "จัดกลุ่มแอปที่อยู่ใน LaunchNow ตอนนี้เข้าโฟลเดอร์ตามหมวดหมู่",
            .confirmAutoOrganize: "จัดกลุ่มแอปอัตโนมัติ?",
            .confirmAutoOrganizeMessage: "ระบบจะจัดเลย์เอาต์ LaunchNow ปัจจุบันใหม่เป็นโฟลเดอร์ตามหมวดหมู่ โดยไม่กระทบแอปจริงในเครื่อง",
            .organize: "จัดกลุ่ม",
            .open: "เปิด",
            .showInFinder: "แสดงใน Finder",
            .renameApp: "เปลี่ยนชื่อ",
            .resetName: "รีเซ็ตชื่อ",
            .save: "บันทึก",
            .renameAppDescription: "ตั้งชื่อที่แสดงใน LaunchNow เท่านั้น โดยไม่เปลี่ยนชื่อไฟล์แอปจริง",
            .renameFolderDescription: "ตั้งชื่อที่แสดงสำหรับโฟลเดอร์นี้",
            .changeIcon: "เปลี่ยนไอคอน",
            .resetIcon: "รีเซ็ตไอคอน",
            .chooseCustomIcon: "เลือกรูปภาพเพื่อใช้เป็นไอคอนของแอปนี้",
            .folders: "โฟลเดอร์",
            .chooseCustomFolderIcon: "เลือกรูปภาพเพื่อใช้เป็นไอคอนของโฟลเดอร์นี้",
            .noFoldersInLaunchpad: "ยังไม่มีโฟลเดอร์ใน Launchpad",
            .removeAppsDescription: "นำแอปออกจาก Launchpad (ไม่ลบแอปออกจากเครื่อง)",
            .searchApps: "ค้นหาแอป",
            .remove: "นำออก",
            .noAppsInLaunchpad: "ยังไม่มีแอปใน Launchpad",
            .noResults: "ไม่พบผลลัพธ์",
            .manageAppLibraries: "จัดการคลังแอปเพิ่มเติม",
            .appLibrariesDescription: "เพิ่มไดรฟ์ภายนอกหรือโฟลเดอร์กำหนดเอง เพื่อให้ LaunchNow ค้นหาแอปนอกตำแหน่งเริ่มต้นได้",
            .systemDirectories: "โฟลเดอร์ระบบ",
            .customDirectories: "โฟลเดอร์กำหนดเอง",
            .noCustomDirectories: "ยังไม่มีโฟลเดอร์กำหนดเอง เพิ่มโฟลเดอร์เพื่อซิงก์แอปเพิ่มเติม",
            .addFolders: "เพิ่มโฟลเดอร์...",
            .restoreDefaults: "คืนค่าเริ่มต้น",
            .exportData: "ส่งออกข้อมูล",
            .importData: "นำเข้าข้อมูล",
            .exportImportDescription: "การส่งออก/นำเข้าจะรวมเลย์เอาต์ โฟลเดอร์ และการตั้งค่า",
            .profiles: "โปรไฟล์",
            .profileName: "ชื่อโปรไฟล์",
            .saveCurrentProfile: "บันทึกโปรไฟล์ปัจจุบัน",
            .renameProfile: "เปลี่ยนชื่อโปรไฟล์",
            .applyProfile: "ใช้",
            .deleteProfile: "ลบ",
            .noProfiles: "ยังไม่มีโปรไฟล์",
            .profilesDescription: "บันทึกเลย์เอาต์และการตั้งค่า LaunchNow หลายชุด แล้วสลับใช้งานได้ทุกเวลา",
            .updatedFormat: "อัปเดต %@",
            .cloudBackup: "สำรองข้อมูลบนคลาวด์",
            .cloudBackupDescription: "เลือกโฟลเดอร์ที่ซิงก์อยู่ เช่น iCloud Drive, Google Drive, Dropbox หรือ OneDrive เพื่อเก็บสำรองโปรไฟล์ออนไลน์",
            .chooseCloudFolder: "เลือกโฟลเดอร์",
            .changeCloudFolder: "เปลี่ยนโฟลเดอร์",
            .clearCloudFolder: "ล้างโฟลเดอร์",
            .backupNow: "สำรองตอนนี้",
            .restoreFromCloud: "กู้คืนจากคลาวด์",
            .noCloudFolder: "ยังไม่ได้เลือกโฟลเดอร์คลาวด์",
            .lastCloudBackupFormat: "สำรองล่าสุด %@",
            .chooseCloudBackupFolder: "เลือกโฟลเดอร์ซิงก์สำหรับสำรองข้อมูล LaunchNow",
            .cloudBackupComplete: "สำรองข้อมูลไปยังโฟลเดอร์คลาวด์แล้ว",
            .cloudBackupFailed: "ไม่สามารถสำรองโปรไฟล์ไปยังโฟลเดอร์คลาวด์ได้",
            .cloudRestoreComplete: "กู้คืนโปรไฟล์จากโฟลเดอร์คลาวด์แล้ว",
            .cloudRestoreFailed: "ไม่สามารถกู้คืนโปรไฟล์จากโฟลเดอร์คลาวด์ได้",
            .versionFormat: "เวอร์ชัน %@",
            .aboutDescription: "ตัวเปิดแอปน้ำหนักเบาที่ให้ความรู้สึกคล้าย Launchpad",
            .autoCheckUpdates: "ตรวจหาอัปเดตอัตโนมัติ",
            .autoCheckUpdatesDescription: "LaunchNow จะตรวจในเบื้องหลังและแจ้งเตือนเมื่อมี release ใหม่",
            .lastAutoUpdateCheckFormat: "ตรวจอัตโนมัติล่าสุด %@",
            .automaticUpdateAvailableFormat: "มีเวอร์ชัน %@ จากการตรวจอัตโนมัติ",
            .automaticUpdateCheckFailed: "การตรวจหาอัปเดตอัตโนมัติครั้งล่าสุดล้มเหลว",
            .checkForUpdates: "ตรวจหาอัปเดต",
            .checkingForUpdates: "กำลังตรวจหาอัปเดต...",
            .appUpToDate: "LaunchNow เป็นเวอร์ชันล่าสุดแล้ว",
            .updateAvailableFormat: "มีเวอร์ชัน %@ ให้ใช้งาน",
            .updateCheckFailed: "ไม่สามารถตรวจหาอัปเดตได้",
            .downloadUpdate: "ดาวน์โหลดอัปเดต",
            .installUpdate: "ติดตั้งอัปเดต",
            .downloadingUpdate: "กำลังดาวน์โหลดอัปเดต...",
            .installingUpdate: "กำลังติดตั้งอัปเดต...",
            .installingUpdateRelaunch: "กำลังติดตั้งอัปเดต LaunchNow จะออกและเปิดใหม่ให้อัตโนมัติ",
            .updateDownloadedFormat: "ดาวน์โหลด %@ แล้ว และเปิดตัวติดตั้งให้แล้ว",
            .updateDownloadFailed: "ไม่สามารถดาวน์โหลดอัปเดตได้",
            .updateInstallFailed: "ไม่สามารถติดตั้งอัปเดตได้",
            .updateNotificationTitleFormat: "มี LaunchNow %@ ให้ใช้งาน",
            .updateNotificationBody: "เปิด Settings ของ LaunchNow เพื่อติดตั้งอัปเดต",
            .uninstall: "ถอนการติดตั้ง",
            .uninstallDescription: "ออกจากแอปและย้ายไปถังขยะ สามารถลบข้อมูลแอปเพิ่มเติมได้",
            .uninstallTitle: "ถอนการติดตั้ง LaunchNow",
            .uninstallWarning: "แอปจะออกและพยายามย้ายตัวเองไปยังถังขยะ คุณสามารถลบข้อมูลของแอปด้วยได้ (Application Support และ preferences)",
            .alsoRemoveData: "ลบข้อมูลแอปด้วย (Application Support และ preferences)",
            .cancel: "ยกเลิก",
            .clear: "ล้าง",
            .reset: "รีเซ็ต",
            .confirmResetLayout: "ยืนยันการรีเซ็ตเลย์เอาต์?",
            .confirmResetLayoutMessage: "ระบบจะรีเซ็ตเลย์เอาต์และสแกนแอปที่มีอยู่ใหม่ โดยจะไม่เพิ่มแอปเข้า Launchpad ให้อัตโนมัติ",
            .confirmClearApps: "ล้างแอปทั้งหมดจาก Launchpad?",
            .confirmClearAppsMessage: "ระบบจะนำแอป โฟลเดอร์ และเลย์เอาต์ทั้งหมดออกจาก Launchpad โดยไม่กระทบแอปจริงบนเครื่อง",
            .removeThisFolder: "นำโฟลเดอร์นี้ออก",
            .choose: "เลือก",
            .add: "เพิ่ม",
            .import: "นำเข้า",
            .chooseFoldersContainingApps: "เลือกโฟลเดอร์ที่มีแอป",
            .chooseExportDestination: "เลือกโฟลเดอร์ปลายทางสำหรับส่งออกข้อมูล LaunchNow",
            .chooseImportFolder: "เลือกโฟลเดอร์ที่เคยส่งออกจาก LaunchNow",
            .selectAppsToAdd: "เลือกแอปที่จะเพิ่มเข้า Launchpad",
            .selectAll: "เลือกทั้งหมด",
            .selectAppsToRemove: "เลือกแอปที่จะนำออกจาก Launchpad",
            .includeFolderApps: "รวมแอปที่อยู่ในโฟลเดอร์",
            .search: "ค้นหา",
            .noAppsFound: "ไม่พบแอป",
            .folderName: "ชื่อโฟลเดอร์",
            .untitledFolder: "ไม่มีชื่อ",
            .categoryDeveloper: "Developer",
            .categoryDesign: "Design",
            .categoryGames: "Games",
            .categoryUtilities: "Utilities",
            .categoryProductivity: "Productivity",
            .categoryEducation: "Education",
            .categoryEntertainment: "Entertainment",
            .categoryMusic: "Music",
            .categoryPhotoVideo: "Photo & Video",
            .categorySocial: "Social",
            .categoryFinance: "Finance",
            .categoryHealth: "Health",
            .categoryLifestyle: "Lifestyle",
            .categoryReference: "Reference",
            .categoryOther: "Other"
        ],
        .japanese: [
            .general: "一般", .appearance: "表示", .gridLayout: "グリッドレイアウト", .appManagement: "アプリ管理", .appSources: "アプリの場所", .data: "データ", .about: "情報",
            .refresh: "更新", .resetLayout: "レイアウトをリセット", .quit: "終了", .language: "言語", .english: "英語", .thai: "タイ語", .japanese: "日本語", .korean: "韓国語", .simplifiedChinese: "中国語（簡体字）", .spanish: "スペイン語", .french: "フランス語", .german: "ドイツ語", .portugueseBrazil: "ポルトガル語（ブラジル）", .indonesian: "インドネシア語", .vietnamese: "ベトナム語", .system: "システム",
            .runInBackground: "バックグラウンドで実行", .runInBackgroundDescription: "LaunchNow を Dock に追加するか、キーボードショートカットですばやく開けます。", .classicLaunchpad: "クラシック Launchpad（フルスクリーン）", .fullscreenLayout: "フルスクリーンのレイアウトと間隔を使用", .scrollingSensitivity: "スクロール感度", .low: "低", .high: "高",
            .columns: "列", .rows: "行", .appColumnsDescription: "1ページあたりのアプリ列数", .appRowsDescription: "1ページあたりのアプリ行数", .itemsPerPage: "1ページの項目数", .addApp: "アプリを追加", .resetApp: "アプリをリセット", .changeIcon: "アイコンを変更", .resetIcon: "アイコンをリセット", .chooseCustomIcon: "このアプリのアイコンとして使う画像を選択してください。", .removeAppsDescription: "Launchpad からアプリを取り除きます（ディスク上のアプリは削除されません）。", .searchApps: "アプリを検索", .remove: "削除", .noAppsInLaunchpad: "Launchpad にアプリがありません。", .noResults: "結果がありません。",
            .manageAppLibraries: "追加のアプリライブラリを管理", .appLibrariesDescription: "外部ドライブやカスタムフォルダを追加して、標準の場所外のアプリも収集できます。", .systemDirectories: "システムフォルダ", .customDirectories: "カスタムフォルダ", .noCustomDirectories: "カスタムフォルダはまだありません。追加するとアプリを同期できます。", .addFolders: "フォルダを追加...", .restoreDefaults: "デフォルトに戻す",
            .exportData: "データを書き出す", .importData: "データを読み込む", .exportImportDescription: "書き出し/読み込みにはレイアウト、フォルダ、設定が含まれます。", .versionFormat: "バージョン %@", .aboutDescription: "Launchpad 風の軽量アプリランチャーです。", .uninstall: "アンインストール", .uninstallDescription: "アプリを終了してゴミ箱へ移動します。アプリデータも削除できます。", .uninstallTitle: "LaunchNow をアンインストール", .uninstallWarning: "アプリは終了し、自身をゴミ箱へ移動しようとします。データ（Application Support と preferences）も削除できます。", .alsoRemoveData: "アプリデータも削除（Application Support と preferences）",
            .cancel: "キャンセル", .clear: "クリア", .reset: "リセット", .confirmResetLayout: "レイアウトをリセットしますか？", .confirmResetLayoutMessage: "レイアウトをリセットし、利用可能なアプリを再スキャンします。Launchpad には自動追加されません。", .confirmClearApps: "Launchpad からすべてのアプリを削除しますか？", .confirmClearAppsMessage: "Launchpad からアプリ、フォルダ、レイアウトを削除します。ディスク上のアプリには影響しません。", .removeThisFolder: "このフォルダを削除", .choose: "選択", .add: "追加", .import: "読み込み", .chooseFoldersContainingApps: "アプリを含むフォルダを選択してください。", .chooseExportDestination: "LaunchNow データの書き出し先フォルダを選択", .chooseImportFolder: "以前に LaunchNow から書き出したフォルダを選択", .selectAppsToAdd: "Launchpad に追加するアプリを選択", .selectAll: "すべて選択", .selectAppsToRemove: "Launchpad から削除するアプリを選択", .includeFolderApps: "フォルダ内のアプリも含める", .search: "検索", .noAppsFound: "アプリが見つかりません", .folderName: "フォルダ名", .untitledFolder: "名称未設定"
        ],
        .korean: [
            .general: "일반", .appearance: "모양", .gridLayout: "그리드 레이아웃", .appManagement: "앱 관리", .appSources: "앱 소스", .data: "데이터", .about: "정보",
            .refresh: "새로 고침", .resetLayout: "레이아웃 재설정", .quit: "종료", .language: "언어", .english: "영어", .thai: "태국어", .japanese: "일본어", .korean: "한국어", .simplifiedChinese: "중국어(간체)", .spanish: "스페인어", .french: "프랑스어", .german: "독일어", .portugueseBrazil: "포르투갈어(브라질)", .indonesian: "인도네시아어", .vietnamese: "베트남어", .system: "시스템",
            .runInBackground: "백그라운드에서 실행", .runInBackgroundDescription: "LaunchNow를 Dock에 추가하거나 키보드 단축키로 창을 빠르게 열 수 있습니다.", .classicLaunchpad: "클래식 Launchpad(전체 화면)", .fullscreenLayout: "전체 화면 레이아웃과 간격 사용", .scrollingSensitivity: "스크롤 감도", .low: "낮음", .high: "높음",
            .columns: "열", .rows: "행", .appColumnsDescription: "페이지당 앱 열 수", .appRowsDescription: "페이지당 앱 행 수", .itemsPerPage: "페이지당 항목", .addApp: "앱 추가", .resetApp: "앱 재설정", .changeIcon: "아이콘 변경", .resetIcon: "아이콘 재설정", .chooseCustomIcon: "이 앱 아이콘으로 사용할 이미지를 선택하세요.", .removeAppsDescription: "Launchpad에서 앱을 제거합니다(디스크의 앱은 삭제되지 않음).", .searchApps: "앱 검색", .remove: "제거", .noAppsInLaunchpad: "Launchpad에 앱이 없습니다.", .noResults: "결과가 없습니다.",
            .manageAppLibraries: "추가 앱 라이브러리 관리", .appLibrariesDescription: "외장 드라이브나 사용자 지정 폴더를 추가하여 기본 위치 외의 앱도 찾을 수 있습니다.", .systemDirectories: "시스템 폴더", .customDirectories: "사용자 지정 폴더", .noCustomDirectories: "아직 사용자 지정 폴더가 없습니다. 추가하면 앱을 동기화할 수 있습니다.", .addFolders: "폴더 추가...", .restoreDefaults: "기본값 복원",
            .exportData: "데이터 내보내기", .importData: "데이터 가져오기", .exportImportDescription: "내보내기/가져오기는 레이아웃, 폴더 및 설정을 포함합니다.", .versionFormat: "버전 %@", .aboutDescription: "Launchpad와 비슷한 가벼운 앱 런처입니다.", .uninstall: "제거", .uninstallDescription: "앱을 종료하고 휴지통으로 이동합니다. 앱 데이터도 제거할 수 있습니다.", .uninstallTitle: "LaunchNow 제거", .uninstallWarning: "앱이 종료되고 자신을 휴지통으로 이동하려고 합니다. 데이터(Application Support 및 preferences)도 제거할 수 있습니다.", .alsoRemoveData: "앱 데이터도 제거(Application Support 및 preferences)",
            .cancel: "취소", .clear: "지우기", .reset: "재설정", .confirmResetLayout: "레이아웃을 재설정할까요?", .confirmResetLayoutMessage: "레이아웃을 재설정하고 사용 가능한 앱을 다시 스캔합니다. Launchpad에는 자동으로 추가되지 않습니다.", .confirmClearApps: "Launchpad의 모든 앱을 지울까요?", .confirmClearAppsMessage: "Launchpad에서 모든 앱, 폴더, 레이아웃을 제거합니다. 디스크의 애플리케이션에는 영향을 주지 않습니다.", .removeThisFolder: "이 폴더 제거", .choose: "선택", .add: "추가", .import: "가져오기", .chooseFoldersContainingApps: "앱이 포함된 폴더를 선택하세요.", .chooseExportDestination: "LaunchNow 데이터를 내보낼 대상 폴더 선택", .chooseImportFolder: "이전에 LaunchNow에서 내보낸 폴더 선택", .selectAppsToAdd: "Launchpad에 추가할 앱 선택", .selectAll: "모두 선택", .selectAppsToRemove: "Launchpad에서 제거할 앱 선택", .includeFolderApps: "폴더 안의 앱 포함", .search: "검색", .noAppsFound: "앱을 찾을 수 없습니다", .folderName: "폴더 이름", .untitledFolder: "제목 없음"
        ],
        .simplifiedChinese: [
            .general: "通用", .appearance: "外观", .gridLayout: "网格布局", .appManagement: "应用管理", .appSources: "应用来源", .data: "数据", .about: "关于",
            .refresh: "刷新", .resetLayout: "重置布局", .quit: "退出", .language: "语言", .english: "英语", .thai: "泰语", .japanese: "日语", .korean: "韩语", .simplifiedChinese: "简体中文", .spanish: "西班牙语", .french: "法语", .german: "德语", .portugueseBrazil: "葡萄牙语（巴西）", .indonesian: "印尼语", .vietnamese: "越南语", .system: "跟随系统",
            .runInBackground: "后台运行", .runInBackgroundDescription: "将 LaunchNow 添加到 Dock，或使用快捷键快速打开窗口。", .classicLaunchpad: "经典 Launchpad（全屏）", .fullscreenLayout: "使用全屏布局和间距", .scrollingSensitivity: "滚动灵敏度", .low: "低", .high: "高",
            .columns: "列", .rows: "行", .appColumnsDescription: "每页应用列数", .appRowsDescription: "每页应用行数", .itemsPerPage: "每页项目数", .addApp: "添加应用", .resetApp: "重置应用", .changeIcon: "更改图标", .resetIcon: "重置图标", .chooseCustomIcon: "选择一张图片作为此应用图标。", .removeAppsDescription: "从 Launchpad 移除应用（不会删除磁盘上的应用）。", .searchApps: "搜索应用", .remove: "移除", .noAppsInLaunchpad: "Launchpad 中没有应用。", .noResults: "没有结果。",
            .manageAppLibraries: "管理额外应用库", .appLibrariesDescription: "添加外置硬盘或自定义文件夹，让 LaunchNow 搜索默认位置之外的应用。", .systemDirectories: "系统目录", .customDirectories: "自定义目录", .noCustomDirectories: "还没有自定义目录。添加一个以同步更多应用。", .addFolders: "添加文件夹...", .restoreDefaults: "恢复默认",
            .exportData: "导出数据", .importData: "导入数据", .exportImportDescription: "导出/导入会包含布局、文件夹和设置。", .versionFormat: "版本 %@", .aboutDescription: "一款轻量的类 Launchpad 应用启动器。", .uninstall: "卸载", .uninstallDescription: "退出应用并移动到废纸篓。也可以移除应用数据。", .uninstallTitle: "卸载 LaunchNow", .uninstallWarning: "应用将退出并尝试将自身移动到废纸篓。你也可以移除其数据（Application Support 和 preferences）。", .alsoRemoveData: "同时移除应用数据（Application Support 和 preferences）",
            .cancel: "取消", .clear: "清除", .reset: "重置", .confirmResetLayout: "确认重置布局？", .confirmResetLayoutMessage: "这将重置布局并重新扫描可用应用。不会自动添加应用到 Launchpad。", .confirmClearApps: "从 Launchpad 清除所有应用？", .confirmClearAppsMessage: "这会从 Launchpad 移除所有应用、文件夹和布局。磁盘上的应用不会受影响。", .removeThisFolder: "移除此文件夹", .choose: "选择", .add: "添加", .import: "导入", .chooseFoldersContainingApps: "选择包含应用的文件夹。", .chooseExportDestination: "选择导出 LaunchNow 数据的目标文件夹", .chooseImportFolder: "选择之前从 LaunchNow 导出的文件夹", .selectAppsToAdd: "选择要添加到 Launchpad 的应用", .selectAll: "全选", .selectAppsToRemove: "选择要从 Launchpad 移除的应用", .includeFolderApps: "包含文件夹内的应用", .search: "搜索", .noAppsFound: "未找到应用", .folderName: "文件夹名称", .untitledFolder: "未命名"
        ],
        .spanish: [
            .general: "General", .appearance: "Apariencia", .gridLayout: "Diseño de cuadrícula", .appManagement: "Gestión de apps", .appSources: "Fuentes de apps", .data: "Datos", .about: "Acerca de",
            .refresh: "Actualizar", .resetLayout: "Restablecer diseño", .quit: "Salir", .language: "Idioma", .english: "Inglés", .thai: "Tailandés", .japanese: "Japonés", .korean: "Coreano", .simplifiedChinese: "Chino simplificado", .spanish: "Español", .french: "Francés", .german: "Alemán", .portugueseBrazil: "Portugués (Brasil)", .indonesian: "Indonesio", .vietnamese: "Vietnamita", .system: "Sistema",
            .runInBackground: "Ejecutar en segundo plano", .runInBackgroundDescription: "Agrega LaunchNow al Dock o usa atajos de teclado para abrir la ventana rápidamente.", .classicLaunchpad: "Launchpad clásico (pantalla completa)", .fullscreenLayout: "Usar diseño y espaciado de pantalla completa", .scrollingSensitivity: "Sensibilidad de desplazamiento", .low: "Baja", .high: "Alta",
            .columns: "Columnas", .rows: "Filas", .appColumnsDescription: "Número de columnas de apps por página", .appRowsDescription: "Número de filas de apps por página", .itemsPerPage: "Elementos por página", .addApp: "Agregar app", .resetApp: "Restablecer apps", .changeIcon: "Cambiar icono", .resetIcon: "Restablecer icono", .chooseCustomIcon: "Elige una imagen para usarla como icono de esta app.", .removeAppsDescription: "Quita apps de Launchpad (no elimina apps del disco).", .searchApps: "Buscar apps", .remove: "Quitar", .noAppsInLaunchpad: "No hay apps en Launchpad.", .noResults: "Sin resultados.",
            .manageAppLibraries: "Gestionar bibliotecas de apps adicionales", .appLibrariesDescription: "Agrega discos externos o carpetas personalizadas para que LaunchNow encuentre apps fuera de las ubicaciones predeterminadas.", .systemDirectories: "Directorios del sistema", .customDirectories: "Directorios personalizados", .noCustomDirectories: "Aún no hay directorios personalizados. Agrega uno para mantener apps extra sincronizadas.", .addFolders: "Agregar carpetas...", .restoreDefaults: "Restaurar valores predeterminados",
            .exportData: "Exportar datos", .importData: "Importar datos", .exportImportDescription: "Exportar/importar incluye tu diseño, carpetas y ajustes.", .versionFormat: "Versión %@", .aboutDescription: "Un lanzador de apps ligero inspirado en Launchpad.", .uninstall: "Desinstalar", .uninstallDescription: "Cierra la app y muévela a la Papelera. También puedes eliminar datos de la app.", .uninstallTitle: "Desinstalar LaunchNow", .uninstallWarning: "La app se cerrará e intentará moverse a la Papelera. También puedes eliminar sus datos (Application Support y preferences).", .alsoRemoveData: "Eliminar también datos de la app (Application Support y preferences)",
            .cancel: "Cancelar", .clear: "Limpiar", .reset: "Restablecer", .confirmResetLayout: "¿Confirmar restablecimiento del diseño?", .confirmResetLayoutMessage: "Esto restablecerá el diseño y volverá a escanear apps disponibles. No agregará apps automáticamente a Launchpad.", .confirmClearApps: "¿Quitar todas las apps de Launchpad?", .confirmClearAppsMessage: "Esto eliminará todas las apps, carpetas y el diseño de Launchpad. Tus aplicaciones en disco no se verán afectadas.", .removeThisFolder: "Quitar esta carpeta", .choose: "Elegir", .add: "Agregar", .import: "Importar", .chooseFoldersContainingApps: "Elige carpetas que contengan apps.", .chooseExportDestination: "Elige una carpeta de destino para exportar datos de LaunchNow", .chooseImportFolder: "Elige una carpeta exportada previamente desde LaunchNow", .selectAppsToAdd: "Selecciona apps para agregar a Launchpad", .selectAll: "Seleccionar todo", .selectAppsToRemove: "Selecciona apps para quitar de Launchpad", .includeFolderApps: "Incluir apps dentro de carpetas", .search: "Buscar", .noAppsFound: "No se encontraron apps", .folderName: "Nombre de carpeta", .untitledFolder: "Sin título"
        ],
        .french: [
            .general: "Général", .appearance: "Apparence", .gridLayout: "Disposition de la grille", .appManagement: "Gestion des apps", .appSources: "Sources d'apps", .data: "Données", .about: "À propos",
            .refresh: "Actualiser", .resetLayout: "Réinitialiser la disposition", .quit: "Quitter", .language: "Langue", .english: "Anglais", .thai: "Thaï", .japanese: "Japonais", .korean: "Coréen", .simplifiedChinese: "Chinois simplifié", .spanish: "Espagnol", .french: "Français", .german: "Allemand", .portugueseBrazil: "Portugais (Brésil)", .indonesian: "Indonésien", .vietnamese: "Vietnamien", .system: "Système",
            .runInBackground: "Exécuter en arrière-plan", .runInBackgroundDescription: "Ajoutez LaunchNow au Dock ou utilisez des raccourcis clavier pour ouvrir la fenêtre rapidement.", .classicLaunchpad: "Launchpad classique (plein écran)", .fullscreenLayout: "Utiliser la disposition et l'espacement plein écran", .scrollingSensitivity: "Sensibilité du défilement", .low: "Faible", .high: "Élevée",
            .columns: "Colonnes", .rows: "Lignes", .appColumnsDescription: "Nombre de colonnes d'apps par page", .appRowsDescription: "Nombre de lignes d'apps par page", .itemsPerPage: "Éléments par page", .addApp: "Ajouter une app", .resetApp: "Réinitialiser les apps", .changeIcon: "Changer l'icône", .resetIcon: "Réinitialiser l'icône", .chooseCustomIcon: "Choisissez une image à utiliser comme icône de cette app.", .removeAppsDescription: "Retire les apps de Launchpad (ne supprime pas les apps du disque).", .searchApps: "Rechercher des apps", .remove: "Retirer", .noAppsInLaunchpad: "Aucune app dans Launchpad.", .noResults: "Aucun résultat.",
            .manageAppLibraries: "Gérer les bibliothèques d'apps supplémentaires", .appLibrariesDescription: "Ajoutez des disques externes ou des dossiers personnalisés pour que LaunchNow trouve des apps au-delà des emplacements par défaut.", .systemDirectories: "Dossiers système", .customDirectories: "Dossiers personnalisés", .noCustomDirectories: "Aucun dossier personnalisé pour le moment. Ajoutez-en un pour synchroniser des apps supplémentaires.", .addFolders: "Ajouter des dossiers...", .restoreDefaults: "Rétablir les valeurs par défaut",
            .exportData: "Exporter les données", .importData: "Importer les données", .exportImportDescription: "L'export/import inclut votre disposition, vos dossiers et vos réglages.", .versionFormat: "Version %@", .aboutDescription: "Un lanceur d'apps léger inspiré de Launchpad.", .uninstall: "Désinstaller", .uninstallDescription: "Quitte l'app et la déplace vers la Corbeille. Vous pouvez aussi supprimer les données de l'app.", .uninstallTitle: "Désinstaller LaunchNow", .uninstallWarning: "L'app va se fermer et tenter de se déplacer vers la Corbeille. Vous pouvez aussi supprimer ses données (Application Support et preferences).", .alsoRemoveData: "Supprimer aussi les données de l'app (Application Support et preferences)",
            .cancel: "Annuler", .clear: "Effacer", .reset: "Réinitialiser", .confirmResetLayout: "Confirmer la réinitialisation de la disposition ?", .confirmResetLayoutMessage: "Cela réinitialisera la disposition et relancera l'analyse des apps disponibles. Les apps ne seront pas ajoutées automatiquement à Launchpad.", .confirmClearApps: "Retirer toutes les apps de Launchpad ?", .confirmClearAppsMessage: "Cela retirera toutes les apps, dossiers et la disposition de Launchpad. Vos applications sur le disque ne seront pas affectées.", .removeThisFolder: "Retirer ce dossier", .choose: "Choisir", .add: "Ajouter", .import: "Importer", .chooseFoldersContainingApps: "Choisissez des dossiers contenant des apps.", .chooseExportDestination: "Choisissez un dossier de destination pour exporter les données LaunchNow", .chooseImportFolder: "Choisissez un dossier précédemment exporté depuis LaunchNow", .selectAppsToAdd: "Sélectionnez les apps à ajouter à Launchpad", .selectAll: "Tout sélectionner", .selectAppsToRemove: "Sélectionnez les apps à retirer de Launchpad", .includeFolderApps: "Inclure les apps dans les dossiers", .search: "Rechercher", .noAppsFound: "Aucune app trouvée", .folderName: "Nom du dossier", .untitledFolder: "Sans titre"
        ],
        .german: [
            .general: "Allgemein", .appearance: "Darstellung", .gridLayout: "Rasterlayout", .appManagement: "App-Verwaltung", .appSources: "App-Quellen", .data: "Daten", .about: "Info",
            .refresh: "Aktualisieren", .resetLayout: "Layout zurücksetzen", .quit: "Beenden", .language: "Sprache", .english: "Englisch", .thai: "Thai", .japanese: "Japanisch", .korean: "Koreanisch", .simplifiedChinese: "Chinesisch (vereinfacht)", .spanish: "Spanisch", .french: "Französisch", .german: "Deutsch", .portugueseBrazil: "Portugiesisch (Brasilien)", .indonesian: "Indonesisch", .vietnamese: "Vietnamesisch", .system: "System",
            .runInBackground: "Im Hintergrund ausführen", .runInBackgroundDescription: "Füge LaunchNow zum Dock hinzu oder verwende Tastaturkurzbefehle, um das Fenster schnell zu öffnen.", .classicLaunchpad: "Klassisches Launchpad (Vollbild)", .fullscreenLayout: "Vollbildlayout und Abstände verwenden", .scrollingSensitivity: "Scroll-Empfindlichkeit", .low: "Niedrig", .high: "Hoch",
            .columns: "Spalten", .rows: "Zeilen", .appColumnsDescription: "Anzahl der App-Spalten pro Seite", .appRowsDescription: "Anzahl der App-Zeilen pro Seite", .itemsPerPage: "Elemente pro Seite", .addApp: "App hinzufügen", .resetApp: "Apps zurücksetzen", .changeIcon: "Icon ändern", .resetIcon: "Icon zurücksetzen", .chooseCustomIcon: "Wähle ein Bild, das als Icon dieser App verwendet wird.", .removeAppsDescription: "Apps aus Launchpad entfernen (löscht keine Apps vom Datenträger).", .searchApps: "Apps suchen", .remove: "Entfernen", .noAppsInLaunchpad: "Keine Apps in Launchpad.", .noResults: "Keine Ergebnisse.",
            .manageAppLibraries: "Zusätzliche App-Bibliotheken verwalten", .appLibrariesDescription: "Füge externe Laufwerke oder eigene Ordner hinzu, damit LaunchNow Apps außerhalb der Standardorte findet.", .systemDirectories: "Systemordner", .customDirectories: "Eigene Ordner", .noCustomDirectories: "Noch keine eigenen Ordner. Füge einen hinzu, um zusätzliche Apps zu synchronisieren.", .addFolders: "Ordner hinzufügen...", .restoreDefaults: "Standardwerte wiederherstellen",
            .exportData: "Daten exportieren", .importData: "Daten importieren", .exportImportDescription: "Export/Import enthält Layout, Ordner und Einstellungen.", .versionFormat: "Version %@", .aboutDescription: "Ein leichter App-Launcher im Launchpad-Stil.", .uninstall: "Deinstallieren", .uninstallDescription: "Beendet die App und verschiebt sie in den Papierkorb. App-Daten können ebenfalls entfernt werden.", .uninstallTitle: "LaunchNow deinstallieren", .uninstallWarning: "Die App wird beendet und versucht, sich in den Papierkorb zu verschieben. Du kannst auch ihre Daten entfernen (Application Support und preferences).", .alsoRemoveData: "Auch App-Daten entfernen (Application Support und preferences)",
            .cancel: "Abbrechen", .clear: "Leeren", .reset: "Zurücksetzen", .confirmResetLayout: "Layout wirklich zurücksetzen?", .confirmResetLayoutMessage: "Dadurch wird das Layout zurückgesetzt und verfügbare Apps werden erneut gescannt. Apps werden nicht automatisch zu Launchpad hinzugefügt.", .confirmClearApps: "Alle Apps aus Launchpad entfernen?", .confirmClearAppsMessage: "Dadurch werden alle Apps, Ordner und das Layout aus Launchpad entfernt. Deine Anwendungen auf dem Datenträger bleiben unverändert.", .removeThisFolder: "Diesen Ordner entfernen", .choose: "Auswählen", .add: "Hinzufügen", .import: "Importieren", .chooseFoldersContainingApps: "Wähle Ordner aus, die Apps enthalten.", .chooseExportDestination: "Wähle einen Zielordner zum Exportieren der LaunchNow-Daten", .chooseImportFolder: "Wähle einen zuvor aus LaunchNow exportierten Ordner", .selectAppsToAdd: "Apps zum Hinzufügen zu Launchpad auswählen", .selectAll: "Alle auswählen", .selectAppsToRemove: "Apps zum Entfernen aus Launchpad auswählen", .includeFolderApps: "Apps in Ordnern einschließen", .search: "Suchen", .noAppsFound: "Keine Apps gefunden", .folderName: "Ordnername", .untitledFolder: "Ohne Titel"
        ],
        .portugueseBrazil: [
            .general: "Geral", .appearance: "Aparência", .gridLayout: "Layout da grade", .appManagement: "Gerenciamento de apps", .appSources: "Fontes de apps", .data: "Dados", .about: "Sobre",
            .refresh: "Atualizar", .resetLayout: "Redefinir layout", .quit: "Sair", .language: "Idioma", .english: "Inglês", .thai: "Tailandês", .japanese: "Japonês", .korean: "Coreano", .simplifiedChinese: "Chinês simplificado", .spanish: "Espanhol", .french: "Francês", .german: "Alemão", .portugueseBrazil: "Português (Brasil)", .indonesian: "Indonésio", .vietnamese: "Vietnamita", .system: "Sistema",
            .runInBackground: "Executar em segundo plano", .runInBackgroundDescription: "Adicione o LaunchNow ao Dock ou use atalhos de teclado para abrir a janela rapidamente.", .classicLaunchpad: "Launchpad clássico (tela cheia)", .fullscreenLayout: "Usar layout e espaçamento de tela cheia", .scrollingSensitivity: "Sensibilidade da rolagem", .low: "Baixa", .high: "Alta",
            .columns: "Colunas", .rows: "Linhas", .appColumnsDescription: "Número de colunas de apps por página", .appRowsDescription: "Número de linhas de apps por página", .itemsPerPage: "Itens por página", .addApp: "Adicionar app", .resetApp: "Redefinir apps", .changeIcon: "Alterar ícone", .resetIcon: "Redefinir ícone", .chooseCustomIcon: "Escolha uma imagem para usar como ícone deste app.", .removeAppsDescription: "Remove apps do Launchpad (não exclui apps do disco).", .searchApps: "Buscar apps", .remove: "Remover", .noAppsInLaunchpad: "Nenhum app no Launchpad.", .noResults: "Nenhum resultado.",
            .manageAppLibraries: "Gerenciar bibliotecas de apps adicionais", .appLibrariesDescription: "Adicione unidades externas ou pastas personalizadas para que o LaunchNow encontre apps além dos locais padrão.", .systemDirectories: "Diretórios do sistema", .customDirectories: "Diretórios personalizados", .noCustomDirectories: "Ainda não há diretórios personalizados. Adicione um para sincronizar apps extras.", .addFolders: "Adicionar pastas...", .restoreDefaults: "Restaurar padrões",
            .exportData: "Exportar dados", .importData: "Importar dados", .exportImportDescription: "Exportar/importar inclui seu layout, pastas e ajustes.", .versionFormat: "Versão %@", .aboutDescription: "Um lançador de apps leve inspirado no Launchpad.", .uninstall: "Desinstalar", .uninstallDescription: "Encerra o app e o move para o Lixo. Você também pode remover dados do app.", .uninstallTitle: "Desinstalar LaunchNow", .uninstallWarning: "O app será encerrado e tentará mover a si mesmo para o Lixo. Você também pode remover seus dados (Application Support e preferences).", .alsoRemoveData: "Também remover dados do app (Application Support e preferences)",
            .cancel: "Cancelar", .clear: "Limpar", .reset: "Redefinir", .confirmResetLayout: "Confirmar redefinição do layout?", .confirmResetLayoutMessage: "Isso redefinirá o layout e verificará novamente os apps disponíveis. Não adicionará apps automaticamente ao Launchpad.", .confirmClearApps: "Remover todos os apps do Launchpad?", .confirmClearAppsMessage: "Isso removerá todos os apps, pastas e o layout do Launchpad. Seus aplicativos no disco não serão afetados.", .removeThisFolder: "Remover esta pasta", .choose: "Escolher", .add: "Adicionar", .import: "Importar", .chooseFoldersContainingApps: "Escolha pastas que contenham apps.", .chooseExportDestination: "Escolha uma pasta de destino para exportar dados do LaunchNow", .chooseImportFolder: "Escolha uma pasta exportada anteriormente do LaunchNow", .selectAppsToAdd: "Selecione apps para adicionar ao Launchpad", .selectAll: "Selecionar tudo", .selectAppsToRemove: "Selecione apps para remover do Launchpad", .includeFolderApps: "Incluir apps dentro de pastas", .search: "Buscar", .noAppsFound: "Nenhum app encontrado", .folderName: "Nome da pasta", .untitledFolder: "Sem título"
        ],
        .indonesian: [
            .general: "Umum", .appearance: "Tampilan", .gridLayout: "Tata letak grid", .appManagement: "Manajemen app", .appSources: "Sumber app", .data: "Data", .about: "Tentang",
            .refresh: "Segarkan", .resetLayout: "Atur ulang tata letak", .quit: "Keluar", .language: "Bahasa", .english: "Inggris", .thai: "Thai", .japanese: "Jepang", .korean: "Korea", .simplifiedChinese: "Tionghoa Sederhana", .spanish: "Spanyol", .french: "Prancis", .german: "Jerman", .portugueseBrazil: "Portugis (Brasil)", .indonesian: "Indonesia", .vietnamese: "Vietnam", .system: "Sistem",
            .runInBackground: "Jalankan di latar belakang", .runInBackgroundDescription: "Tambahkan LaunchNow ke Dock atau gunakan pintasan keyboard untuk membuka jendela dengan cepat.", .classicLaunchpad: "Launchpad klasik (layar penuh)", .fullscreenLayout: "Gunakan tata letak dan jarak layar penuh", .scrollingSensitivity: "Sensitivitas gulir", .low: "Rendah", .high: "Tinggi",
            .columns: "Kolom", .rows: "Baris", .appColumnsDescription: "Jumlah kolom app per halaman", .appRowsDescription: "Jumlah baris app per halaman", .itemsPerPage: "Item per halaman", .addApp: "Tambah app", .resetApp: "Atur ulang app", .changeIcon: "Ubah ikon", .resetIcon: "Atur ulang ikon", .chooseCustomIcon: "Pilih gambar untuk digunakan sebagai ikon app ini.", .removeAppsDescription: "Hapus app dari Launchpad (tidak menghapus app dari disk).", .searchApps: "Cari app", .remove: "Hapus", .noAppsInLaunchpad: "Tidak ada app di Launchpad.", .noResults: "Tidak ada hasil.",
            .manageAppLibraries: "Kelola pustaka app tambahan", .appLibrariesDescription: "Tambahkan drive eksternal atau folder khusus agar LaunchNow dapat menemukan app di luar lokasi bawaan.", .systemDirectories: "Direktori sistem", .customDirectories: "Direktori khusus", .noCustomDirectories: "Belum ada direktori khusus. Tambahkan satu untuk menyinkronkan app tambahan.", .addFolders: "Tambah folder...", .restoreDefaults: "Pulihkan bawaan",
            .exportData: "Ekspor data", .importData: "Impor data", .exportImportDescription: "Ekspor/impor mencakup tata letak, folder, dan pengaturan.", .versionFormat: "Versi %@", .aboutDescription: "Peluncur app ringan bergaya Launchpad.", .uninstall: "Copot pemasangan", .uninstallDescription: "Tutup app dan pindahkan ke Tong Sampah. Anda juga dapat menghapus data app.", .uninstallTitle: "Copot LaunchNow", .uninstallWarning: "App akan ditutup dan mencoba memindahkan dirinya ke Tong Sampah. Anda juga dapat menghapus datanya (Application Support dan preferences).", .alsoRemoveData: "Hapus juga data app (Application Support dan preferences)",
            .cancel: "Batal", .clear: "Bersihkan", .reset: "Atur ulang", .confirmResetLayout: "Konfirmasi atur ulang tata letak?", .confirmResetLayoutMessage: "Ini akan mengatur ulang tata letak dan memindai ulang app yang tersedia. App tidak akan ditambahkan otomatis ke Launchpad.", .confirmClearApps: "Hapus semua app dari Launchpad?", .confirmClearAppsMessage: "Ini akan menghapus semua app, folder, dan tata letak dari Launchpad. Aplikasi di disk tidak terpengaruh.", .removeThisFolder: "Hapus folder ini", .choose: "Pilih", .add: "Tambah", .import: "Impor", .chooseFoldersContainingApps: "Pilih folder yang berisi app.", .chooseExportDestination: "Pilih folder tujuan untuk mengekspor data LaunchNow", .chooseImportFolder: "Pilih folder yang sebelumnya diekspor dari LaunchNow", .selectAppsToAdd: "Pilih app untuk ditambahkan ke Launchpad", .selectAll: "Pilih semua", .selectAppsToRemove: "Pilih app untuk dihapus dari Launchpad", .includeFolderApps: "Sertakan app di dalam folder", .search: "Cari", .noAppsFound: "App tidak ditemukan", .folderName: "Nama folder", .untitledFolder: "Tanpa judul"
        ],
        .vietnamese: [
            .general: "Chung", .appearance: "Giao diện", .gridLayout: "Bố cục lưới", .appManagement: "Quản lý ứng dụng", .appSources: "Nguồn ứng dụng", .data: "Dữ liệu", .about: "Giới thiệu",
            .refresh: "Làm mới", .resetLayout: "Đặt lại bố cục", .quit: "Thoát", .language: "Ngôn ngữ", .english: "Tiếng Anh", .thai: "Tiếng Thái", .japanese: "Tiếng Nhật", .korean: "Tiếng Hàn", .simplifiedChinese: "Tiếng Trung giản thể", .spanish: "Tiếng Tây Ban Nha", .french: "Tiếng Pháp", .german: "Tiếng Đức", .portugueseBrazil: "Tiếng Bồ Đào Nha (Brazil)", .indonesian: "Tiếng Indonesia", .vietnamese: "Tiếng Việt", .system: "Hệ thống",
            .runInBackground: "Chạy trong nền", .runInBackgroundDescription: "Thêm LaunchNow vào Dock hoặc dùng phím tắt để mở cửa sổ nhanh chóng.", .classicLaunchpad: "Launchpad cổ điển (toàn màn hình)", .fullscreenLayout: "Dùng bố cục và khoảng cách toàn màn hình", .scrollingSensitivity: "Độ nhạy cuộn", .low: "Thấp", .high: "Cao",
            .columns: "Cột", .rows: "Hàng", .appColumnsDescription: "Số cột ứng dụng mỗi trang", .appRowsDescription: "Số hàng ứng dụng mỗi trang", .itemsPerPage: "Mục mỗi trang", .addApp: "Thêm ứng dụng", .resetApp: "Đặt lại ứng dụng", .changeIcon: "Đổi biểu tượng", .resetIcon: "Đặt lại biểu tượng", .chooseCustomIcon: "Chọn hình ảnh để dùng làm biểu tượng cho ứng dụng này.", .removeAppsDescription: "Xóa ứng dụng khỏi Launchpad (không xóa ứng dụng trên ổ đĩa).", .searchApps: "Tìm ứng dụng", .remove: "Xóa", .noAppsInLaunchpad: "Không có ứng dụng trong Launchpad.", .noResults: "Không có kết quả.",
            .manageAppLibraries: "Quản lý thư viện ứng dụng bổ sung", .appLibrariesDescription: "Thêm ổ đĩa ngoài hoặc thư mục tùy chỉnh để LaunchNow tìm ứng dụng ngoài các vị trí mặc định.", .systemDirectories: "Thư mục hệ thống", .customDirectories: "Thư mục tùy chỉnh", .noCustomDirectories: "Chưa có thư mục tùy chỉnh. Thêm một thư mục để đồng bộ ứng dụng bổ sung.", .addFolders: "Thêm thư mục...", .restoreDefaults: "Khôi phục mặc định",
            .exportData: "Xuất dữ liệu", .importData: "Nhập dữ liệu", .exportImportDescription: "Xuất/nhập bao gồm bố cục, thư mục và cài đặt.", .versionFormat: "Phiên bản %@", .aboutDescription: "Trình mở ứng dụng nhẹ giống Launchpad.", .uninstall: "Gỡ cài đặt", .uninstallDescription: "Thoát ứng dụng và chuyển vào Thùng rác. Bạn cũng có thể xóa dữ liệu ứng dụng.", .uninstallTitle: "Gỡ cài đặt LaunchNow", .uninstallWarning: "Ứng dụng sẽ thoát và cố gắng tự chuyển vào Thùng rác. Bạn cũng có thể xóa dữ liệu của ứng dụng (Application Support và preferences).", .alsoRemoveData: "Xóa cả dữ liệu ứng dụng (Application Support và preferences)",
            .cancel: "Hủy", .clear: "Xóa", .reset: "Đặt lại", .confirmResetLayout: "Xác nhận đặt lại bố cục?", .confirmResetLayoutMessage: "Thao tác này sẽ đặt lại bố cục và quét lại các ứng dụng có sẵn. Ứng dụng sẽ không được tự động thêm vào Launchpad.", .confirmClearApps: "Xóa tất cả ứng dụng khỏi Launchpad?", .confirmClearAppsMessage: "Thao tác này sẽ xóa tất cả ứng dụng, thư mục và bố cục khỏi Launchpad. Ứng dụng trên ổ đĩa không bị ảnh hưởng.", .removeThisFolder: "Xóa thư mục này", .choose: "Chọn", .add: "Thêm", .import: "Nhập", .chooseFoldersContainingApps: "Chọn thư mục có chứa ứng dụng.", .chooseExportDestination: "Chọn thư mục đích để xuất dữ liệu LaunchNow", .chooseImportFolder: "Chọn thư mục đã từng xuất từ LaunchNow", .selectAppsToAdd: "Chọn ứng dụng để thêm vào Launchpad", .selectAll: "Chọn tất cả", .selectAppsToRemove: "Chọn ứng dụng để xóa khỏi Launchpad", .includeFolderApps: "Bao gồm ứng dụng trong thư mục", .search: "Tìm kiếm", .noAppsFound: "Không tìm thấy ứng dụng", .folderName: "Tên thư mục", .untitledFolder: "Chưa đặt tên"
        ]
    ]
}
