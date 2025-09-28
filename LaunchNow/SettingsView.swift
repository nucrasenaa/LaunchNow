import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SwiftData

struct SettingsView: View {
    @ObservedObject var appStore: AppStore
    @State private var showResetConfirm = false
    @State private var showResetAppsConfirm = false
    @State private var isImportSheetPresented = false
    @State private var isRemoveSheetPresented = false

    // คำนวณความสูงสูงสุดของแผง (80% ของความสูงหน้าจอที่มองเห็น)
    private var sheetMaxHeight: CGFloat {
        let h = NSScreen.main?.visibleFrame.height ?? 900
        return h * 0.8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("LaunchNow")
                    .font(.title)
                Text("v\(getVersion())")
                    .font(.footnote)
                Spacer()
                Button {
                    appStore.isSetting = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.bold())
                        .foregroundStyle(.placeholder)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical)

            // Section 1: Appearance & Interaction
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance & Interaction")
                    .font(.headline)

                HStack {
                    Text("Classic Launchpad (Fullscreen)")
                    Spacer()
                    Toggle(isOn: $appStore.isFullscreenMode) { }
                        .toggleStyle(.switch)
                }
                HStack(alignment: .top) {
                    Text("Scrolling sensitivity")
                    VStack {
                        Slider(value: $appStore.scrollSensitivity, in: 0.01...0.99)
                        HStack {
                            Text("Low").font(.footnote)
                            Spacer()
                            Text("High").font(.footnote)
                        }
                    }
                }
                HStack {
                    Text("Automatically run on background: add LaunchNow to dock or use keyboard shortcuts to open the application window")
                    Spacer()
                }
            }
            .padding(.bottom, 8)

            Divider()

            // Section 2: Grid Layout
            VStack(alignment: .leading, spacing: 12) {
                Text("Grid Layout")
                    .font(.headline)

                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Columns")
                            Spacer()
                            Stepper(value: $appStore.gridColumns, in: 3...12) {
                                Text("\(appStore.gridColumns)")
                            }
                            .frame(width: 180)
                            .onChange(of: appStore.gridColumns) { _, _ in
                                appStore.triggerGridRefresh()
                            }
                        }
                        Text("Number of app columns per page")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Rows")
                            Spacer()
                            Stepper(value: $appStore.gridRows, in: 2...8) {
                                Text("\(appStore.gridRows)")
                            }
                            .frame(width: 180)
                            .onChange(of: appStore.gridRows) { _, _ in
                                appStore.triggerGridRefresh()
                            }
                        }
                        Text("Number of app rows per page")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Items per page")
                    Spacer()
                    Text("\(appStore.gridRows * appStore.gridColumns)")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            Divider()

            // Section 3: App Management
            VStack(alignment: .leading, spacing: 12) {
                Text("App Management")
                    .font(.headline)

                HStack(spacing: 12) {
                    Button {
                        if appStore.availableApps.isEmpty {
                            appStore.performInitialScanIfNeeded()
                        }
                        isImportSheetPresented = true
                    } label: {
                        Label("Add App", systemImage: "plus.app")
                    }
                    .sheet(isPresented: $isImportSheetPresented) {
                        ImportAppsSheet(appStore: appStore, isPresented: $isImportSheetPresented)
                            .frame(minWidth: 640, minHeight: 420)   // ลด minHeight ลงอีก
                            .frame(maxHeight: sheetMaxHeight)       // จำกัดไม่เกิน 80% ของจอ
                    }

                    Button {
                        isRemoveSheetPresented = true
                    } label: {
                        Label("Remove App", systemImage: "trash.slash")
                    }
                    .sheet(isPresented: $isRemoveSheetPresented) {
                        RemoveAppsSheet(appStore: appStore, isPresented: $isRemoveSheetPresented)
                            .frame(minWidth: 640, minHeight: 420)   // ลด minHeight ลงอีก
                            .frame(maxHeight: sheetMaxHeight)       // จำกัดไม่เกิน 80% ของจอ
                    }

                    Button {
                        showResetAppsConfirm = true
                    } label: {
                        Label("Reset App", systemImage: "trash")
                            .foregroundStyle(Color.red)
                    }
                    .alert("Clear all apps from Launchpad?", isPresented: $showResetAppsConfirm) {
                        Button("Clear", role: .destructive) { appStore.resetImportedApps() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will remove all apps, folders and layout from Launchpad. Your applications on disk are not affected.")
                    }
                }
            }
            .padding(.vertical, 8)

            Divider()

            // Section 4: App Settings Backup
            VStack(alignment: .leading, spacing: 12) {
                Text("App Settings Backup")
                    .font(.headline)

                HStack(spacing: 12) {
                    Button {
                        importDataFolder()
                    } label: {
                        Label("Import App Setting", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        exportDataFolder()
                    } label: {
                        Label("Export App Setting", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .padding(.vertical, 8)

            Divider()

            // Section 5: Maintenance
            VStack(alignment: .leading, spacing: 12) {
                Text("Maintenance")
                    .font(.headline)

                HStack {
                    Button {
                        showResetConfirm = true
                    } label: {
                        Label("Reset Layout", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(Color.red)
                    }
                    .alert("Confirm to reset layout?", isPresented: $showResetConfirm) {
                        Button("Reset", role: .destructive) { appStore.resetLayout() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will reset layout and rescan available apps. It won’t auto-add apps to Launchpad.")
                    }

                    Spacer()

                    Button {
                        exit(0)
                    } label: {
                        Label("Quit", systemImage: "xmark.circle")
                            .foregroundStyle(Color.red)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .onAppear {
            if appStore.availableApps.isEmpty {
                appStore.performInitialScanIfNeeded()
            }
        }
    }
    
    func getVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
    }

    // MARK: - Export / Import Application Support Data
    private func supportDirectoryURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent("LaunchNow", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func exportDataFolder() {
        do {
            let sourceDir = try supportDirectoryURL()
            // Write settings JSON into the source directory so it’s included in the copy
            try writeSettingsFile(to: sourceDir)

            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose"
            panel.message = "Choose a destination folder to export LaunchNow data"
            if panel.runModal() == .OK, let destParent = panel.url {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let folderName = "LaunchNow_Export_" + formatter.string(from: Date())
                let destDir = destParent.appendingPathComponent(folderName, isDirectory: true)
                try copyDirectory(from: sourceDir, to: destDir)
            }
        } catch {
            // You could present an alert here if you want
        }
    }

    private func importDataFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a folder previously exported from LaunchNow"
        if panel.runModal() == .OK, let srcDir = panel.url {
            do {
                guard isValidExportFolder(srcDir) else { return }
                let destDir = try supportDirectoryURL()
                if srcDir.standardizedFileURL == destDir.standardizedFileURL { return }
                try replaceDirectory(with: srcDir, at: destDir)

                // Read settings back from imported folder and apply to AppStore
                try applyImportedSettings(from: destDir)

                // Then apply order/folders and refresh UI/cache
                appStore.applyOrderAndFolders()
                appStore.refresh()
            } catch {
                // You could present an alert here if you want
            }
        }
    }

    private func copyDirectory(from src: URL, to dst: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
        }
        try fm.copyItem(at: src, to: dst)
    }

    private func replaceDirectory(with src: URL, at dst: URL) throws {
        let fm = FileManager.default
        let parent = dst.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
        }
        try fm.copyItem(at: src, to: dst)
    }

    private func isValidExportFolder(_ folder: URL) -> Bool {
        let fm = FileManager.default
        let storeURL = folder.appendingPathComponent("Data.store")
        guard fm.fileExists(atPath: storeURL.path) else { return false }
        do {
            let config = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(for: TopItemData.self, PageEntryData.self, configurations: config)
            let ctx = container.mainContext
            let pageEntries = try ctx.fetch(FetchDescriptor<PageEntryData>())
            if !pageEntries.isEmpty { return true }
            let legacyEntries = try ctx.fetch(FetchDescriptor<TopItemData>())
            return !legacyEntries.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Settings.json (include grid layout & scroll sensitivity)
    private struct ExportedSettings: Codable {
        let version: Int
        let isFullscreenMode: Bool
        let gridColumns: Int
        let gridRows: Int
        let scrollSensitivity: Double
    }

    private func settingsFileURL(in folder: URL) -> URL {
        folder.appendingPathComponent("Settings.json", conformingTo: .json)
    }

    private func writeSettingsFile(to folder: URL) throws {
        let settings = ExportedSettings(
            version: 1,
            isFullscreenMode: appStore.isFullscreenMode,
            gridColumns: appStore.gridColumns,
            gridRows: appStore.gridRows,
            scrollSensitivity: appStore.scrollSensitivity
        )
        let data = try JSONEncoder().encode(settings)
        try data.write(to: settingsFileURL(in: folder), options: [.atomic])
    }

    private func applyImportedSettings(from folder: URL) throws {
        let url = settingsFileURL(in: folder)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(ExportedSettings.self, from: data)

        // Apply on main thread so SwiftUI updates correctly; AppStore didSet already persists to UserDefaults
        DispatchQueue.main.async {
            // Order: fullscreen first, then grid (triggers compaction/refresh), then sensitivity
            self.appStore.isFullscreenMode = decoded.isFullscreenMode
            self.appStore.gridColumns = decoded.gridColumns
            self.appStore.gridRows = decoded.gridRows
            self.appStore.scrollSensitivity = decoded.scrollSensitivity
        }
    }
}

struct ImportAppsSheet: View {
    @ObservedObject var appStore: AppStore
    @Binding var isPresented: Bool
    @State private var selection = Set<String>()
    @State private var searchText: String = ""

    private var filteredApps: [AppInfo] {
        guard !searchText.isEmpty else { return appStore.availableApps }
        return appStore.availableApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                // Title with padding and bold
                Text("Select applications to add to Launchpad")
                    .font(.headline.bold())
                    .lineLimit(1)
                    .layoutPriority(1)
                    .padding(.vertical, 8)
                Spacer()
                TextField("Search apps", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300) // wider to avoid wrapping title
            }
            .padding(.horizontal)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(filteredApps, id: \.id) { app in
                        HStack(spacing: 10) {
                            Toggle(isOn: Binding(
                                get: { selection.contains(app.id) },
                                set: { isOn in
                                    if isOn { selection.insert(app.id) }
                                    else { selection.remove(app.id) }
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .interpolation(.high)
                                        .antialiased(true)
                                        .frame(width: 24, height: 24)
                                    Text(app.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(app.url.deletingPathExtension().lastPathComponent)
                                        .foregroundColor(.secondary)
                                        .font(.footnote)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                        .padding(.horizontal)
                        .help(app.url.path)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(minHeight: 320) // ลดส่วนแสดงรายการลงอีก

            HStack {
                Button("Select All") {
                    selection = Set(filteredApps.map { $0.id })
                }
                Button("Clear") {
                    selection.removeAll()
                }
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                Button("Import") {
                    let selectedInfos = appStore.availableApps.filter { selection.contains($0.id) }
                    appStore.importSelectedApps(fromAppInfos: selectedInfos)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .onReceive(appStore.$availableApps) { _ in
            selection = selection.filter { id in appStore.availableApps.contains { $0.id == id } }
        }
    }
}

struct RemoveAppsSheet: View {
    @ObservedObject var appStore: AppStore
    @Binding var isPresented: Bool
    @State private var selection = Set<String>()
    @State private var searchText: String = ""
    @State private var includeFolderApps: Bool = true

    private var allAppsInLaunchpad: [AppInfo] {
        var list: [AppInfo] = []
        list.append(contentsOf: appStore.apps)
        if includeFolderApps {
            for folder in appStore.folders {
                list.append(contentsOf: folder.apps)
            }
        }
        var unique: [AppInfo] = []
        var seen = Set<String>()
        for a in list {
            if !seen.contains(a.id) {
                seen.insert(a.id)
                unique.append(a)
            }
        }
        return unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredApps: [AppInfo] {
        guard !searchText.isEmpty else { return allAppsInLaunchpad }
        return allAppsInLaunchpad.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                // Title with padding and bold
                Text("Select applications to remove from Launchpad")
                    .font(.headline.bold())
                    .lineLimit(1)
                    .layoutPriority(1)
                    .padding(.vertical, 8)
                Spacer()
                TextField("Search apps", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }
            .padding(.horizontal)

            HStack {
                Toggle("Include apps inside folders", isOn: $includeFolderApps)
                Spacer()
            }
            .padding(.horizontal)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(filteredApps, id: \.id) { app in
                        HStack(spacing: 10) {
                            Toggle(isOn: Binding(
                                get: { selection.contains(app.id) },
                                set: { isOn in
                                    if isOn { selection.insert(app.id) }
                                    else { selection.remove(app.id) }
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .interpolation(.high)
                                        .antialiased(true)
                                        .frame(width: 24, height: 24)
                                    Text(app.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(app.url.deletingPathExtension().lastPathComponent)
                                        .foregroundColor(.secondary)
                                        .font(.footnote)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                        .padding(.horizontal)
                        .help(app.url.path)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(minHeight: 300) // ลดลงอีก

            HStack {
                Button("Select All") {
                    selection = Set(filteredApps.map { $0.id })
                }
                Button("Clear") {
                    selection.removeAll()
                }
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                Button("Remove") {
                    let selectedInfos = allAppsInLaunchpad.filter { selection.contains($0.id) }
                    appStore.removeSelectedApps(fromAppInfos: selectedInfos)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .onChange(of: includeFolderApps) { _ in
            selection.removeAll()
        }
        .onReceive(appStore.$apps) { _ in
            selection = selection.filter { id in allAppsInLaunchpad.contains { $0.id == id } }
        }
        .onReceive(appStore.$folders) { _ in
            selection = selection.filter { id in allAppsInLaunchpad.contains { $0.id == id } }
        }
    }
}
