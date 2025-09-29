import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SwiftData

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case layout
    case apps
    case data
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .layout: return "Grid Layout"
        case .apps: return "App Management"
        case .data: return "Data"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.pointed.fill"
        case .layout: return "square.grid.3x3.fill"
        case .apps:
            // macOS 12.6 compatible symbol
            return "square.grid.2x2.fill"
        case .data: return "tray.and.arrow.down.fill"
        case .about: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: return .blue
        case .appearance: return .purple
        case .layout: return .green
        case .apps: return .orange
        case .data: return .teal
        case .about: return .gray
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appStore: AppStore

    // Sheet / alert states
    @State private var showResetConfirm = false
    @State private var showResetAppsConfirm = false
    @State private var isImportSheetPresented = false
    @State private var isRemoveSheetPresented = false // kept for compatibility (not used in new UI)
    @State private var showUninstallSheet = false
    @State private var alsoRemoveData = true

    // UI state
    @State private var selected: SettingsSection = .general
    @State private var tempLanguage: String = Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "English"

    // App list search (Apps pane)
    @State private var appListSearchText: String = ""

    // Max sheet height (80% of visible screen height)
    private var sheetMaxHeight: CGFloat {
        let h = NSScreen.main?.visibleFrame.height ?? 900
        return h * 0.8
    }

    // Preferred size for Settings window
    private var preferredWidth: CGFloat {
        let w = NSScreen.main?.visibleFrame.width ?? 1440
        return w * 0.6
    }
    private var preferredHeight: CGFloat {
        let h = NSScreen.main?.visibleFrame.height ?? 900
        return h * 0.6
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                sidebar
                Divider()
                content
            }
            // Width = 80% of screen width, Height = 60% of screen height
            .frame(width: preferredWidth, height: preferredHeight)

            // Close button
            Button {
                appStore.isSetting = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding()
        }
        .onAppear {
            if appStore.availableApps.isEmpty {
                appStore.performInitialScanIfNeeded()
            }
        }
        .sheet(isPresented: $isImportSheetPresented) {
            ImportAppsSheet(appStore: appStore, isPresented: $isImportSheetPresented)
                .frame(minWidth: 640, minHeight: 420)
                .frame(maxHeight: sheetMaxHeight)
        }
        // Kept for compatibility; no longer presented from Apps pane
        .sheet(isPresented: $isRemoveSheetPresented) {
            RemoveAppsSheet(appStore: appStore, isPresented: $isRemoveSheetPresented)
                .frame(minWidth: 640, minHeight: 420)
                .frame(maxHeight: sheetMaxHeight)
        }
        .sheet(isPresented: $showUninstallSheet) { uninstallSheet }
        .alert("Confirm to reset layout?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { appStore.resetLayout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset layout and rescan available apps. It won’t auto-add apps to Launchpad.")
        }
        .alert("Clear all apps from Launchpad?", isPresented: $showResetAppsConfirm) {
            Button("Clear", role: .destructive) { appStore.resetImportedApps() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all apps, folders and layout from Launchpad. Your applications on disk are not affected.")
        }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App title
            VStack(alignment: .leading, spacing: 2) {
                Text("LaunchNow")
                    .font(.title3.bold())
                Text("v\(getVersion())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(SettingsSection.allCases) { section in
                        Button {
                            selected = section
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: section.symbol)
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .padding(8)
                                    .background(
                                        Circle().fill(section.tint)
                                    )

                                Text(section.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected == section ? section.tint.opacity(0.15) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.top, 6)
            }

            Spacer()
        }
        .frame(width: 240)
    }

    // MARK: - Content
    private var content: some View {
        VStack(spacing: 0) {
            // Section title
            HStack {
                Text(selected.title)
                    .font(.title2.bold())
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selected {
                    case .general: generalPane
                    case .appearance: appearancePane
                    case .layout: layoutPane
                    case .apps: appsPane
                    case .data: dataPane
                    case .about: aboutPane
                    }
                }
                .padding(20)
            }

            Divider()
                .padding(.top, 8)

            // Bottom action bar
            HStack {
                Button {
                    appStore.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    showResetConfirm = true
                } label: {
                    Label("Reset Layout", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    exit(0)
                } label: {
                    Label("Quit", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(12)
            .background(.bar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Individual panes
    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Language")
                    .font(.headline)
                Picker("", selection: $tempLanguage) {
                    Text("English").tag("English")
                    Text("System").tag("System")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 200)
                .disabled(true)
                Text("This feature is in development.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Run in background")
                    .font(.headline)
                Text("Add LaunchNow to the Dock or use keyboard shortcuts to open the window quickly.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Classic Launchpad (Fullscreen)")
                    .font(.headline)
                Toggle(isOn: $appStore.isFullscreenMode) {
                    Text("Use fullscreen layout and spacing")
                }
                .toggleStyle(.switch)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Scrolling sensitivity")
                    .font(.headline)
                Slider(value: $appStore.scrollSensitivity, in: 0.01...0.99)
                    .frame(maxWidth: 380)
                HStack {
                    Text("Low").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Text("High").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: 380)
            }
        }
    }

    private var layoutPane: some View {
        // Convert Int properties to stepped sliders
        let columnsBinding = Binding<Double>(
            get: { Double(appStore.gridColumns) },
            set: { appStore.gridColumns = Int($0.rounded()) }
        )
        let rowsBinding = Binding<Double>(
            get: { Double(appStore.gridRows) },
            set: { appStore.gridRows = Int($0.rounded()) }
        )

        return VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Columns").font(.headline)
                    Spacer()
                    Text("\(appStore.gridColumns)")
                        .foregroundStyle(.secondary)
                }
                Slider(value: columnsBinding, in: 3...12, step: 1)
                    .frame(maxWidth: 380)
                HStack {
                    Text("3").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Text("12").font(.footnote).foregroundStyle(.secondary)
                }
                Text("Number of app columns per page")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Rows").font(.headline)
                    Spacer()
                    Text("\(appStore.gridRows)")
                        .foregroundStyle(.secondary)
                }
                Slider(value: rowsBinding, in: 2...8, step: 1)
                    .frame(maxWidth: 380)
                HStack {
                    Text("2").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Text("8").font(.footnote).foregroundStyle(.secondary)
                }
                Text("Number of app rows per page")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Items per page")
                    .font(.headline)
                Spacer()
                Text("\(appStore.gridRows * appStore.gridColumns)")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 380)
        }
    }

    // MARK: - Apps pane (Add + Reset + searchable remove list)
    private var appsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top actions
            HStack(spacing: 12) {
                Button {
                    if appStore.availableApps.isEmpty {
                        appStore.performInitialScanIfNeeded()
                    }
                    isImportSheetPresented = true
                } label: {
                    Label("Add App", systemImage: "plus.app")
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    showResetAppsConfirm = true
                } label: {
                    Label("Reset App", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Text("Remove apps from Launchpad (does not delete apps from disk).")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Search
            TextField("Search apps", text: $appListSearchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)

            // List
            VStack(spacing: 10) {
                ForEach(filteredAppsForRemoveList, id: \.id) { app in
                    HStack(spacing: 12) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .frame(width: 32, height: 32)
                            .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.body.weight(.semibold))
                            Text(app.url.deletingPathExtension().lastPathComponent)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            appStore.removeSelectedApps(fromAppInfos: [app])
                        } label: {
                            Text("Remove")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .help(app.url.path)
                }

                if filteredAppsForRemoveList.isEmpty {
                    Text(appListSearchText.isEmpty ? "No apps in Launchpad." : "No results.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    // Aggregate all apps currently in Launchpad (including inside folders), unique + sorted
    private var allAppsInLaunchpad: [AppInfo] {
        var list: [AppInfo] = []
        list.append(contentsOf: appStore.apps)
        for folder in appStore.folders {
            list.append(contentsOf: folder.apps)
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

    private var filteredAppsForRemoveList: [AppInfo] {
        guard !appListSearchText.isEmpty else { return allAppsInLaunchpad }
        return allAppsInLaunchpad.filter { $0.name.localizedCaseInsensitiveContains(appListSearchText) }
    }

    private var dataPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    exportDataFolder()
                } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                Button {
                    importDataFolder()
                } label: {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }

            Text("Export/Import includes your layout, folders and settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(14)
                VStack(alignment: .leading) {
                    Text("LaunchNow")
                        .font(.title3.bold())
                    Text("Version \(getVersion())")
                        .foregroundStyle(.secondary)
                }
            }
            Text("A lightweight Launchpad-like app launcher.")
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 8)

            // Uninstall is here (moved from Apps)
            HStack(spacing: 12) {
                Button {
                    showUninstallSheet = true
                } label: {
                    Label("Uninstall", systemImage: "trash.circle")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Text("Quit the app and move it to the Trash. You can also remove app data.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Uninstall sheet
    private var uninstallSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Uninstall LaunchNow")
                .font(.title2.bold())
            Text("The app will quit and attempt to move itself to the Trash. You can also remove its data (Application Support and preferences).")
                .foregroundStyle(.secondary)

            Toggle("Also remove app data (Application Support and preferences)", isOn: $alsoRemoveData)

            HStack {
                Spacer()
                Button("Cancel") {
                    showUninstallSheet = false
                }
                Button(role: .destructive) {
                    showUninstallSheet = false
                    performUninstall(removeData: alsoRemoveData)
                } label: {
                    Text("Uninstall")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 480)
    }

    // MARK: - Helpers
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
            // Handle error if desired
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
                try applyImportedSettings(from: destDir)
                appStore.applyOrderAndFolders()
                appStore.refresh()
            } catch {
                // Handle error if desired
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
        DispatchQueue.main.async {
            self.appStore.isFullscreenMode = decoded.isFullscreenMode
            self.appStore.gridColumns = decoded.gridColumns
            self.appStore.gridRows = decoded.gridRows
            self.appStore.scrollSensitivity = decoded.scrollSensitivity
        }
    }

    // MARK: - Uninstall
    private func performUninstall(removeData: Bool) {
        let appPath = Bundle.main.bundlePath
        let supportPath = (try? supportDirectoryURL().path) ?? ""
        let prefsDomain = Bundle.main.bundleIdentifier ?? ""
        let bundleID = Bundle.main.bundleIdentifier ?? ""

        let script = """
        #!/bin/bash
        APP_PATH="$1"
        REMOVE_DATA="$2"
        SUPPORT_PATH="$3"
        PREFS_DOMAIN="$4"
        BUNDLE_ID="$5"

        TRASH="$HOME/.Trash"
        mkdir -p "$TRASH"
        BASENAME="$(basename "$APP_PATH")"
        DEST="$TRASH/$BASENAME"
        i=0
        while [ -e "$DEST" ]; do
          i=$((i+1))
          DEST="$TRASH/$BASENAME $i"
        done

        ATTEMPTS=200
        while [ $ATTEMPTS -gt 0 ]; do
          /usr/bin/osascript -e 'try
            set p to POSIX file "'"$APP_PATH"'"
            tell application "Finder" to delete p
          end try' >/dev/null 2>&1 && break
          mv "$APP_PATH" "$DEST" >/dev/null 2>&1 && break
          sleep 0.1
          ATTEMPTS=$((ATTEMPTS-1))
        done

        if [ -e "$APP_PATH" ]; then
          rm -rf "$APP_PATH"
        fi

        PLIST="$HOME/Library/Preferences/com.apple.dock.plist"
        if [ -f "$PLIST" ]; then
          COUNT=0
          while /usr/libexec/PlistBuddy -c "Print :persistent-apps:$COUNT" "$PLIST" >/dev/null 2>&1; do
            COUNT=$((COUNT+1))
          done
          IDX=$((COUNT-1))
          while [ $IDX -ge 0 ]; do
            BID=$(/usr/libexec/PlistBuddy -c "Print :persistent-apps:$IDX:tile-data:bundle-identifier" "$PLIST" 2>/dev/null || echo "")
            URLSTR=$(/usr/libexec/PlistBuddy -c "Print :persistent-apps:$IDX:tile-data:file-data:_CFURLString" "$PLIST" 2>/dev/null || echo "")
            if [ "$BID" = "$BUNDLE_ID" ] || [[ "$URLSTR" == "file://$APP_PATH"* ]] || [[ "$URLSTR" == *"/$(basename "$APP_PATH")"* ]]; then
              /usr/libexec/PlistBuddy -c "Delete :persistent-apps:$IDX" "$PLIST" >/dev/null 2>&1
            fi
            IDX=$((IDX-1))
          done
          /usr/bin/killall Dock >/dev/null 2>&1
        fi

        if [ "$REMOVE_DATA" = "1" ]; then
          if [ -n "$SUPPORT_PATH" ]; then
            rm -rf "$SUPPORT_PATH"
          fi
          if [ -n "$PREFS_DOMAIN" ]; then
            defaults delete "$PREFS_DOMAIN" >/dev/null 2>&1
          fi
        fi

        rm -- "$0" >/dev/null 2>&1 &
        """

        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("launchnow_uninstall_\(UUID().uuidString).sh")

        do {
            try script.write(to: tmpURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpURL.path)

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [tmpURL.path, appPath, removeData ? "1" : "0", supportPath, prefsDomain, bundleID]
            try proc.run()
        } catch {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: appPath)])
        }

        DispatchQueue.main.async {
            let app = NSApplication.shared
            for w in app.windows {
                w.orderOut(nil)
                w.close()
            }
            app.hide(nil)
            app.setActivationPolicy(.prohibited)
            app.terminate(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NSRunningApplication.current.forceTerminate()
                exit(0)
            }
        }
    }
}

// MARK: - Import/Remove sheets (kept for compatibility; not used by the new Apps pane)
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
                Text("Select applications to add to Launchpad")
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
            .frame(minHeight: 320)

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

struct RemoveAppsSheet: View { // unused by new UI, kept to avoid breaking references
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
            .frame(minHeight: 300)

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
