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

    var body: some View {
        VStack {
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
            .padding()
            
            VStack {
                HStack {
                    Text("Automatically run on background: add LaunchNow to dock or use keyboard shortcuts to open the application window")
                    Spacer()
                }
            }
            .padding()

            Divider()
            
            VStack(spacing: 12) {
                HStack {
                    Text("Classic Launchpad (Fullscreen)")
                    Spacer()
                    Toggle(isOn: $appStore.isFullscreenMode) { }
                        .toggleStyle(.switch)
                }
                HStack {
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
                
                // MARK: - Grid layout settings (Rows / Columns)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grid layout")
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
                .padding(.top, 8)
            }
            .padding()
            
            Divider()
            
            HStack(spacing: 12) {
                Button {
                    // เตรียม availableApps หากยังไม่มี
                    if appStore.availableApps.isEmpty {
                        appStore.performInitialScanIfNeeded()
                    }
                    isImportSheetPresented = true
                } label: {
                    Label("Import App", systemImage: "square.and.arrow.down.on.square")
                }
                .sheet(isPresented: $isImportSheetPresented) {
                    ImportAppsSheet(appStore: appStore, isPresented: $isImportSheetPresented)
                        .frame(minWidth: 560, minHeight: 640)
                }
                
                Button {
                    // 打开移除应用的面板
                    isRemoveSheetPresented = true
                } label: {
                    Label("Remove App", systemImage: "trash.slash")
                }
                .sheet(isPresented: $isRemoveSheetPresented) {
                    RemoveAppsSheet(appStore: appStore, isPresented: $isRemoveSheetPresented)
                        .frame(minWidth: 560, minHeight: 640)
                }
                
                Button {
                    exportDataFolder()
                } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }

                Button {
                    importDataFolder()
                } label: {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                }
            }
            .padding()
            
            Divider()

            HStack {
                Button {
                    appStore.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Spacer()

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
                                
                Button {
                    exit(0)
                } label: {
                    Label("Quit", systemImage: "xmark.circle")
                        .foregroundStyle(Color.red)
                }
            }
            .padding()
        }
        .padding()
        .onAppear {
            // สแกนรายชื่อแอปล่วงหน้าเพื่อให้พร้อมในแผง Import
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
        } catch { }
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
                appStore.applyOrderAndFolders()
                appStore.refresh()
            } catch { }
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
}

struct ImportAppsSheet: View {
    @ObservedObject var appStore: AppStore
    @Binding var isPresented: Bool
    @State private var selection = Set<String>() // ใช้ path เป็น key
    @State private var searchText: String = ""

    private var filteredApps: [AppInfo] {
        guard !searchText.isEmpty else { return appStore.availableApps }
        return appStore.availableApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Select applications to add to Launchpad")
                    .font(.headline)
                Spacer()
                TextField("Search apps", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
            }
            .padding(.horizontal)

            // แสดงรายการพร้อม Checkbox
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
            .frame(minHeight: 460)

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
            .padding(.bottom, 12)
        }
        .onReceive(appStore.$availableApps) { _ in
            // ล้าง selection ที่ไม่อยู่ในรายการ (กรณีสแกนอัปเดต)
            selection = selection.filter { id in appStore.availableApps.contains { $0.id == id } }
        }
    }
}

struct RemoveAppsSheet: View {
    @ObservedObject var appStore: AppStore
    @Binding var isPresented: Bool
    @State private var selection = Set<String>() // use app path as key
    @State private var searchText: String = ""
    @State private var includeFolderApps: Bool = true

    private var allAppsInLaunchpad: [AppInfo] {
        var list: [AppInfo] = []
        // top-level apps
        list.append(contentsOf: appStore.apps)
        if includeFolderApps {
            // apps inside folders
            for folder in appStore.folders {
                list.append(contentsOf: folder.apps)
            }
        }
        // unique by path and sort by name
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
            HStack {
                Text("Select applications to remove from Launchpad")
                    .font(.headline)
                Spacer()
                TextField("Search apps", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
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
            .frame(minHeight: 460)

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
            .padding(.bottom, 12)
        }
        .onChange(of: includeFolderApps) { _ in
            // reset selection when scope changes to avoid stale selections
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
