import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SwiftData

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case layout
    case apps
    case appSources
    case data
    case about

    var id: String { rawValue }

    func title(_ localization: LocalizationManager) -> String {
        switch self {
        case .general: return localization.text(.general)
        case .appearance: return localization.text(.appearance)
        case .layout: return localization.text(.gridLayout)
        case .apps: return localization.text(.appManagement)
        case .appSources: return localization.text(.appSources)
        case .data: return localization.text(.data)
        case .about: return localization.text(.about)
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
        case .appSources: return "externaldrive.fill"
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
        case .appSources: return .cyan
        case .data: return .teal
        case .about: return .gray
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var keyboardShortcutManager = KeyboardShortcutManager.shared

    // Sheet / alert states
    @State private var showResetConfirm = false
    @State private var showResetAppsConfirm = false
    @State private var showAutoOrganizeConfirm = false
    @State private var isImportSheetPresented = false
    @State private var isRemoveSheetPresented = false // kept for compatibility (not used in new UI)
    @State private var showUninstallSheet = false
    @State private var alsoRemoveData = true
    @State private var isCheckingForUpdates = false
    @State private var isInstallingUpdate = false
    @State private var availableUpdate: AppUpdateInfo?
    @State private var updateStatusMessage: String?
    @State private var profileName: String = ""
    @State private var renamingProfileID: String?

    // UI state
    @State private var selected: SettingsSection = .general
    @State private var selectedLanguage: AppLanguage = LocalizationManager.shared.language

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
        .alert(localization.text(.confirmResetLayout), isPresented: $showResetConfirm) {
            Button(localization.text(.reset), role: .destructive) { appStore.resetLayout() }
            Button(localization.text(.cancel), role: .cancel) {}
        } message: {
            Text(localization.text(.confirmResetLayoutMessage))
        }
        .alert(localization.text(.confirmClearApps), isPresented: $showResetAppsConfirm) {
            Button(localization.text(.clear), role: .destructive) { appStore.resetImportedApps() }
            Button(localization.text(.cancel), role: .cancel) {}
        } message: {
            Text(localization.text(.confirmClearAppsMessage))
        }
        .alert(localization.text(.confirmAutoOrganize), isPresented: $showAutoOrganizeConfirm) {
            Button(localization.text(.organize)) { appStore.autoOrganizeApps() }
            Button(localization.text(.cancel), role: .cancel) {}
        } message: {
            Text(localization.text(.confirmAutoOrganizeMessage))
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

                                Text(section.title(localization))
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
                Text(selected.title(localization))
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
                    case .appSources: appSourcesPane
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
                    Label(localization.text(.refresh), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    showResetConfirm = true
                } label: {
                    Label(localization.text(.resetLayout), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    exit(0)
                } label: {
                    Label(localization.text(.quit), systemImage: "xmark.circle")
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
                Text(localization.text(.language))
                    .font(.headline)
                Picker("", selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(localization.text(language.displayNameKey)).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 200)
                .onChange(of: selectedLanguage) { _, newValue in
                    localization.language = newValue
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(.keyboardShortcut))
                    .font(.headline)
                Picker("", selection: keyboardShortcutBinding) {
                    ForEach(KeyboardShortcutPreset.allCases) { shortcut in
                        Text(shortcutTitle(shortcut)).tag(shortcut)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 240)

                Text(localization.text(.keyboardShortcutDescription))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(.searchScope))
                    .font(.headline)
                Picker("", selection: $appStore.searchScope) {
                    ForEach(LaunchpadSearchScope.allCases) { scope in
                        Text(searchScopeTitle(scope)).tag(scope)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .onChange(of: appStore.searchScope) { _, newValue in
                    if newValue == .allApplications, appStore.availableApps.isEmpty {
                        appStore.performInitialScanIfNeeded()
                    }
                }

                Text(localization.text(.searchScopeDescription))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(.runInBackground))
                    .font(.headline)
                Text(localization.text(.runInBackgroundDescription))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var keyboardShortcutBinding: Binding<KeyboardShortcutPreset> {
        Binding(
            get: { keyboardShortcutManager.preset },
            set: { keyboardShortcutManager.setPreset($0) }
        )
    }

    private func shortcutTitle(_ shortcut: KeyboardShortcutPreset) -> String {
        switch shortcut {
        case .disabled:
            return localization.text(.shortcutDisabled)
        case .optionSpace:
            return localization.text(.shortcutOptionSpace)
        case .controlSpace:
            return localization.text(.shortcutControlSpace)
        case .commandShiftSpace:
            return localization.text(.shortcutCommandShiftSpace)
        case .controlOptionSpace:
            return localization.text(.shortcutControlOptionSpace)
        case .commandOptionL:
            return localization.text(.shortcutCommandOptionL)
        }
    }

    private func searchScopeTitle(_ scope: LaunchpadSearchScope) -> String {
        switch scope {
        case .launchNowApps:
            return localization.text(.searchLaunchNowApps)
        case .allApplications:
            return localization.text(.searchAllApplications)
        }
    }

    private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(.appearancePreset))
                    .font(.headline)
                Picker("", selection: appearancePresetBinding) {
                    ForEach(LaunchpadAppearancePreset.allCases) { preset in
                        Text(appearancePresetTitle(preset)).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 520)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(.classicLaunchpad))
                    .font(.headline)
                Toggle(isOn: $appStore.isFullscreenMode) {
                    Text(localization.text(.fullscreenLayout))
                }
                .toggleStyle(.switch)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(.scrollingSensitivity))
                    .font(.headline)
                Slider(value: $appStore.scrollSensitivity, in: 0.01...0.99)
                    .frame(maxWidth: 380)
                HStack {
                    Text(localization.text(.low)).font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Text(localization.text(.high)).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: 380)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(localization.text(.background))
                    .font(.headline)

                HStack {
                    Text(localization.text(.backgroundPreset))
                    Spacer()
                    Picker("", selection: $appStore.backgroundPreset) {
                        ForEach(LaunchpadBackgroundPreset.allCases) { preset in
                            Text(backgroundPresetTitle(preset)).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }
                .frame(maxWidth: 380)

                if appStore.backgroundPreset == .customImage {
                    HStack(spacing: 10) {
                        Button {
                            appStore.presentChooseBackgroundImagePanel()
                        } label: {
                            Label(localization.text(.choose), systemImage: "photo")
                        }
                        .buttonStyle(.bordered)

                        if appStore.customBackgroundImageURL != nil {
                            Button {
                                appStore.resetCustomBackgroundImage()
                            } label: {
                                Label(localization.text(.reset), systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                HStack {
                    Text(localization.text(.backgroundOpacity))
                    Spacer()
                    Text("\(Int(appStore.backgroundOpacity * 100))%")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 380)
                Slider(value: $appStore.backgroundOpacity, in: 0.2...1.0)
                    .frame(maxWidth: 380)

                HStack {
                    Text(localization.text(.backgroundBlur))
                    Spacer()
                    Text("\(Int(appStore.backgroundBlur))")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 380)
                Slider(value: $appStore.backgroundBlur, in: 0...40)
                    .frame(maxWidth: 380)
            }
        }
    }

    private var appearancePresetBinding: Binding<LaunchpadAppearancePreset> {
        Binding(
            get: { appStore.appearancePreset },
            set: { appStore.applyAppearancePreset($0) }
        )
    }

    private func appearancePresetTitle(_ preset: LaunchpadAppearancePreset) -> String {
        switch preset {
        case .glass:
            return localization.text(.appearanceGlass)
        case .dark:
            return localization.text(.appearanceDark)
        case .light:
            return localization.text(.appearanceLight)
        case .compact:
            return localization.text(.appearanceCompact)
        case .classicLaunchpad:
            return localization.text(.appearanceClassicLaunchpad)
        }
    }

    private func backgroundPresetTitle(_ preset: LaunchpadBackgroundPreset) -> String {
        switch preset {
        case .system:
            return localization.text(.backgroundSystem)
        case .aurora:
            return localization.text(.backgroundAurora)
        case .graphite:
            return localization.text(.backgroundGraphite)
        case .sunset:
            return localization.text(.backgroundSunset)
        case .forest:
            return localization.text(.backgroundForest)
        case .customImage:
            return localization.text(.backgroundCustomImage)
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
                    Text(localization.text(.columns)).font(.headline)
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
                Text(localization.text(.appColumnsDescription))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(localization.text(.rows)).font(.headline)
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
                Text(localization.text(.appRowsDescription))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(localization.text(.itemsPerPage))
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
                    Label(localization.text(.addApp), systemImage: "plus.app")
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    showResetAppsConfirm = true
                } label: {
                    Label(localization.text(.resetApp), systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    showAutoOrganizeConfirm = true
                } label: {
                    Label(localization.text(.autoOrganizeApps), systemImage: "square.grid.3x3.fill")
                }
                .buttonStyle(.bordered)
                .disabled(allAppsInLaunchpad.isEmpty)
            }

            Text(localization.text(.removeAppsDescription))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(localization.text(.autoOrganizeAppsDescription))
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Search
            TextField(localization.text(.searchApps), text: $appListSearchText)
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

                        Button {
                            appStore.presentRenameAppPanel(for: app)
                        } label: {
                            Label(localization.text(.renameApp), systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)

                        if appStore.hasCustomDisplayName(for: app) {
                            Button {
                                appStore.resetAppDisplayName(for: app)
                            } label: {
                                Label(localization.text(.resetName), systemImage: "text.badge.xmark")
                            }
                            .buttonStyle(.bordered)
                        }

                        Button {
                            appStore.presentChangeIconPanel(for: app)
                        } label: {
                            Label(localization.text(.changeIcon), systemImage: "photo")
                        }
                        .buttonStyle(.bordered)

                        if appStore.hasCustomIcon(for: app) {
                            Button {
                                appStore.resetCustomIcon(for: app)
                            } label: {
                                Label(localization.text(.resetIcon), systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(role: .destructive) {
                            appStore.removeSelectedApps(fromAppInfos: [app])
                        } label: {
                            Text(localization.text(.remove))
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
                    Text(appListSearchText.isEmpty ? localization.text(.noAppsInLaunchpad) : localization.text(.noResults))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            }

            Divider().padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                Text(localization.text(.folders))
                    .font(.headline)

                ForEach(filteredFoldersForIconList, id: \.id) { folder in
                    HStack(spacing: 12) {
                        Image(nsImage: folder.icon(of: 32))
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .frame(width: 32, height: 32)
                            .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.name)
                                .font(.body.weight(.semibold))
                            Text("\(folder.apps.count)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            appStore.presentChangeFolderIconPanel(for: folder)
                        } label: {
                            Label(localization.text(.changeIcon), systemImage: "photo")
                        }
                        .buttonStyle(.bordered)

                        if appStore.hasCustomFolderIcon(for: folder) {
                            Button {
                                appStore.resetCustomFolderIcon(for: folder)
                            } label: {
                                Label(localization.text(.resetIcon), systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                }

                if filteredFoldersForIconList.isEmpty {
                    Text(appListSearchText.isEmpty ? localization.text(.noFoldersInLaunchpad) : localization.text(.noResults))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - App Sources pane
    private var appSourcesPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(.manageAppLibraries))
                    .font(.headline)
                Text(localization.text(.appLibrariesDescription))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(localization.text(.systemDirectories))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(appStore.systemApplicationSearchPaths, id: \.self) { path in
                    appSourceRow(title: displayName(for: path), path: path, isCustom: false)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(localization.text(.customDirectories))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                if appStore.customApplicationSearchPaths.isEmpty {
                    Text(localization.text(.noCustomDirectories))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(appStore.customApplicationSearchPaths, id: \.self) { path in
                        appSourceRow(title: displayName(for: path), path: path, isCustom: true)
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    presentAddAppSourcePanel()
                } label: {
                    Label(localization.text(.addFolders), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    appStore.restoreDefaultApplicationSearchPaths()
                } label: {
                    Label(localization.text(.restoreDefaults), systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(appStore.customApplicationSearchPaths.isEmpty)
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

    private var filteredFoldersForIconList: [FolderInfo] {
        guard !appListSearchText.isEmpty else { return appStore.folders }
        return appStore.folders.filter { $0.name.localizedCaseInsensitiveContains(appListSearchText) }
    }

    private var dataPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(localization.text(.profiles))
                    .font(.headline)
                Text(localization.text(.profilesDescription))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    TextField(localization.text(.profileName), text: $profileName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)

                    Button {
                        commitProfileNameAction()
                    } label: {
                        Label(
                            renamingProfileID == nil ? localization.text(.saveCurrentProfile) : localization.text(.renameProfile),
                            systemImage: renamingProfileID == nil ? "plus.circle" : "pencil"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if renamingProfileID != nil {
                        Button {
                            renamingProfileID = nil
                            profileName = ""
                        } label: {
                            Text(localization.text(.cancel))
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if appStore.profiles.isEmpty {
                    Text(localization.text(.noProfiles))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 8) {
                        ForEach(appStore.profiles) { profile in
                            profileRow(profile)
                        }
                    }
                    .frame(maxWidth: 560)
                }
            }

            Divider().padding(.vertical, 4)

            HStack(spacing: 12) {
                Button {
                    exportDataFolder()
                } label: {
                    Label(localization.text(.exportData), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                Button {
                    importDataFolder()
                } label: {
                    Label(localization.text(.importData), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }

            Text(localization.text(.exportImportDescription))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func commitProfileNameAction() {
        let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let renamingProfileID {
            appStore.renameProfile(id: renamingProfileID, to: name)
            self.renamingProfileID = nil
        } else {
            appStore.saveCurrentProfile(named: name)
        }
        profileName = ""
    }

    private func profileRow(_ profile: AppStore.ProfileSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.body.weight(.semibold))
                Text(localization.text(.updatedFormat, profileDateFormatter.string(from: profile.updatedAt)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appStore.applyProfile(id: profile.id)
            } label: {
                Label(localization.text(.applyProfile), systemImage: "arrow.down.doc")
            }
            .buttonStyle(.bordered)

            Button {
                renamingProfileID = profile.id
                profileName = profile.name
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
            .help(localization.text(.renameProfile))

            Button {
                if renamingProfileID == profile.id {
                    renamingProfileID = nil
                    profileName = ""
                }
                appStore.deleteProfile(id: profile.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .help(localization.text(.deleteProfile))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private var profileDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
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
                    Text(localization.text(.versionFormat, getVersion()))
                        .foregroundStyle(.secondary)
                }
            }
            Text(localization.text(.aboutDescription))
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        checkForUpdates()
                    } label: {
                        Label(localization.text(.checkForUpdates), systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCheckingForUpdates)

                    if let availableUpdate {
                        Button {
                            installUpdate(availableUpdate)
                        } label: {
                            Label(localization.text(.installUpdate), systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isInstallingUpdate)
                    }
                }

                if isCheckingForUpdates || isInstallingUpdate {
                    ProgressView()
                        .controlSize(.small)
                }

                if let updateStatusMessage {
                    Text(updateStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Divider().padding(.vertical, 8)

            // Uninstall is here (moved from Apps)
            HStack(spacing: 12) {
                Button {
                    showUninstallSheet = true
                } label: {
                    Label(localization.text(.uninstall), systemImage: "trash.circle")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Text(localization.text(.uninstallDescription))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func checkForUpdates() {
        isCheckingForUpdates = true
        updateStatusMessage = localization.text(.checkingForUpdates)
        availableUpdate = nil
        Task {
            do {
                let update = try await AppUpdateManager.shared.checkForUpdate()
                await MainActor.run {
                    availableUpdate = update
                    updateStatusMessage = update.map { localization.text(.updateAvailableFormat, $0.version) } ?? localization.text(.appUpToDate)
                    isCheckingForUpdates = false
                }
            } catch {
                await MainActor.run {
                    updateStatusMessage = localization.text(.updateCheckFailed)
                    isCheckingForUpdates = false
                }
            }
        }
    }

    private func installUpdate(_ update: AppUpdateInfo) {
        isInstallingUpdate = true
        updateStatusMessage = localization.text(.installingUpdate)
        Task {
            do {
                let destinationURL = try await AppUpdateManager.shared.downloadAndInstall(update)
                await MainActor.run {
                    updateStatusMessage = update.packageKind == .zip
                        ? localization.text(.installingUpdateRelaunch)
                        : localization.text(.updateDownloadedFormat, destinationURL.lastPathComponent)
                    isInstallingUpdate = false
                }
            } catch {
                await MainActor.run {
                    updateStatusMessage = localization.text(.updateInstallFailed)
                    isInstallingUpdate = false
                }
            }
        }
    }

    // MARK: - Uninstall sheet
    private var uninstallSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localization.text(.uninstallTitle))
                .font(.title2.bold())
            Text(localization.text(.uninstallWarning))
                .foregroundStyle(.secondary)

            Toggle(localization.text(.alsoRemoveData), isOn: $alsoRemoveData)

            HStack {
                Spacer()
                Button(localization.text(.cancel)) {
                    showUninstallSheet = false
                }
                Button(role: .destructive) {
                    showUninstallSheet = false
                    performUninstall(removeData: alsoRemoveData)
                } label: {
                    Text(localization.text(.uninstall))
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 480)
    }

    @ViewBuilder
    private func appSourceRow(title: String, path: String, isCustom: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isCustom ? "folder.fill" : "externaldrive.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((isCustom ? Color.orange : Color.blue).opacity(0.85))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(path)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isCustom {
                Button {
                    appStore.removeCustomApplicationSearchPath(path)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help(localization.text(.removeThisFolder))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .help(path)
    }

    private func presentAddAppSourcePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = localization.text(.add)
        panel.message = localization.text(.chooseFoldersContainingApps)
        if AppPanelPresenter.runModal(panel) == .OK {
            appStore.addCustomApplicationSearchPaths(from: panel.urls)
        }
    }

    private func displayName(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        return name.isEmpty ? path : name
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
            panel.prompt = localization.text(.choose)
            panel.message = localization.text(.chooseExportDestination)
            if AppPanelPresenter.runModal(panel) == .OK, let destParent = panel.url {
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
        panel.prompt = localization.text(.import)
        panel.message = localization.text(.chooseImportFolder)
        if AppPanelPresenter.runModal(panel) == .OK, let srcDir = panel.url {
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
        let appearancePreset: String?
        let backgroundPreset: String?
        let backgroundOpacity: Double?
        let backgroundBlur: Double?
        let customBackgroundImagePath: String?
    }

    private func settingsFileURL(in folder: URL) -> URL {
        folder.appendingPathComponent("Settings.json", conformingTo: .json)
    }

    private func writeSettingsFile(to folder: URL) throws {
        let settings = ExportedSettings(
            version: 2,
            isFullscreenMode: appStore.isFullscreenMode,
            gridColumns: appStore.gridColumns,
            gridRows: appStore.gridRows,
            scrollSensitivity: appStore.scrollSensitivity,
            appearancePreset: appStore.appearancePreset.rawValue,
            backgroundPreset: appStore.backgroundPreset.rawValue,
            backgroundOpacity: appStore.backgroundOpacity,
            backgroundBlur: appStore.backgroundBlur,
            customBackgroundImagePath: appStore.customBackgroundImagePath
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
            self.appStore.applyImportedBackgroundSettings(
                presetRawValue: decoded.backgroundPreset,
                appearancePresetRawValue: decoded.appearancePreset,
                opacity: decoded.backgroundOpacity,
                blur: decoded.backgroundBlur,
                customImagePath: decoded.customBackgroundImagePath
            )
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
    @ObservedObject private var localization = LocalizationManager.shared
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
                Text(localization.text(.selectAppsToAdd))
                    .font(.headline.bold())
                    .lineLimit(1)
                    .layoutPriority(1)
                    .padding(.vertical, 8)
                Spacer()
                TextField(localization.text(.searchApps), text: $searchText)
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
                Button(localization.text(.selectAll)) {
                    selection = Set(filteredApps.map { $0.id })
                }
                Button(localization.text(.clear)) {
                    selection.removeAll()
                }
                Spacer()
                Button(localization.text(.cancel)) {
                    isPresented = false
                }
                Button(localization.text(.import)) {
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
    @ObservedObject private var localization = LocalizationManager.shared
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
                Text(localization.text(.selectAppsToRemove))
                    .font(.headline.bold())
                    .lineLimit(1)
                    .layoutPriority(1)
                    .padding(.vertical, 8)
                Spacer()
                TextField(localization.text(.searchApps), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }
            .padding(.horizontal)

            HStack {
                Toggle(localization.text(.includeFolderApps), isOn: $includeFolderApps)
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
                Button(localization.text(.selectAll)) {
                    selection = Set(filteredApps.map { $0.id })
                }
                Button(localization.text(.clear)) {
                    selection.removeAll()
                }
                Spacer()
                Button(localization.text(.cancel)) {
                    isPresented = false
                }
                Button(localization.text(.remove)) {
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
        .onChange(of: includeFolderApps) { _, _ in
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
