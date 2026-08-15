import SwiftUI

struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case basics
        case preferences
        case ready
    }

    @ObservedObject var appStore: AppStore
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var keyboardShortcutManager = KeyboardShortcutManager.shared

    @State private var step: Step = .basics
    @State private var selectedLanguage: AppLanguage
    @State private var selectedShortcut: KeyboardShortcutPreset
    @State private var shouldScanApps = true
    @State private var useFullscreenMode: Bool
    @State private var selectedSearchScope: LaunchpadSearchScope

    init(appStore: AppStore) {
        self.appStore = appStore
        _selectedLanguage = State(initialValue: LocalizationManager.shared.language)
        _selectedShortcut = State(initialValue: KeyboardShortcutManager.shared.preset)
        _useFullscreenMode = State(initialValue: appStore.isFullscreenMode)
        _selectedSearchScope = State(initialValue: appStore.searchScope)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            Group {
                switch step {
                case .basics:
                    basicsStep
                case .preferences:
                    preferencesStep
                case .ready:
                    readyStep
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 282, alignment: .top)

            Divider()
            footer
        }
        .padding(26)
        .frame(width: 620)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 30, x: 0, y: 18)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 54, height: 54)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.text(.onboardingTitle))
                        .font(.title2.bold())
                    Text(localization.text(.onboardingDescription))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Color.accentColor : Color.primary.opacity(0.12))
                        .frame(height: 5)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle(
                title: localization.text(.onboardingBasicsTitle),
                detail: localization.text(.onboardingBasicsDescription),
                systemImage: "sparkles"
            )

            settingRow(title: localization.text(.onboardingLanguageTitle), systemImage: "globe") {
                Picker("", selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(localization.text(language.displayNameKey)).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 230)
                .onChange(of: selectedLanguage) { _, newValue in
                    localization.language = newValue
                }
            }

            settingRow(title: localization.text(.onboardingShortcutTitle), systemImage: "keyboard") {
                Picker("", selection: $selectedShortcut) {
                    ForEach(KeyboardShortcutPreset.allCases) { shortcut in
                        Text(shortcutTitle(shortcut)).tag(shortcut)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 230)
            }
        }
    }

    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                title: localization.text(.onboardingPreferencesTitle),
                detail: localization.text(.onboardingPreferencesDescription),
                systemImage: "slider.horizontal.3"
            )

            settingRow(title: localization.text(.onboardingSearchScopeTitle), systemImage: "magnifyingglass") {
                Picker("", selection: $selectedSearchScope) {
                    ForEach(LaunchpadSearchScope.allCases) { scope in
                        Text(searchScopeTitle(scope)).tag(scope)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 230)
            }

            Toggle(isOn: $shouldScanApps) {
                settingLabel(
                    title: localization.text(.onboardingScanAppsTitle),
                    detail: localization.text(.onboardingScanAppsDescription),
                    systemImage: "square.grid.2x2"
                )
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: $useFullscreenMode) {
                settingLabel(
                    title: localization.text(.onboardingFullscreenTitle),
                    detail: localization.text(.onboardingFullscreenDescription),
                    systemImage: "arrow.up.left.and.arrow.down.right"
                )
            }
            .toggleStyle(.checkbox)
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                title: localization.text(.onboardingReadyTitle),
                detail: localization.text(.onboardingReadyDescription),
                systemImage: "checkmark.seal"
            )

            VStack(alignment: .leading, spacing: 10) {
                summaryRow(
                    title: localization.text(.onboardingLanguageTitle),
                    value: localization.text(selectedLanguage.displayNameKey),
                    systemImage: "globe"
                )
                summaryRow(
                    title: localization.text(.onboardingShortcutTitle),
                    value: shortcutTitle(selectedShortcut),
                    systemImage: "keyboard"
                )
                summaryRow(
                    title: localization.text(.onboardingSearchScopeTitle),
                    value: searchScopeTitle(selectedSearchScope),
                    systemImage: "magnifyingglass"
                )
                summaryRow(
                    title: localization.text(.onboardingScanAppsTitle),
                    value: shouldScanApps ? localization.text(.onboardingEnabled) : localization.text(.onboardingDisabled),
                    systemImage: "square.grid.2x2"
                )
                summaryRow(
                    title: localization.text(.onboardingFullscreenTitle),
                    value: useFullscreenMode ? localization.text(.onboardingEnabled) : localization.text(.onboardingDisabled),
                    systemImage: "arrow.up.left.and.arrow.down.right"
                )
            }
            .padding(14)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var footer: some View {
        HStack {
            if step != .basics {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        step = Step(rawValue: step.rawValue - 1) ?? .basics
                    }
                } label: {
                    Label(localization.text(.onboardingBack), systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if step != .ready {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        step = Step(rawValue: step.rawValue + 1) ?? .ready
                    }
                } label: {
                    Label(localization.text(.onboardingNext), systemImage: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    appStore.completeOnboarding(
                        language: selectedLanguage,
                        shortcut: selectedShortcut,
                        isFullscreen: useFullscreenMode,
                        shouldScanApps: shouldScanApps,
                        searchScope: selectedSearchScope
                    )
                } label: {
                    Label(localization.text(.onboardingStart), systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.top, 20)
    }

    private func stepTitle(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func settingRow<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            content()
        }
    }

    private func settingLabel(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func searchScopeTitle(_ scope: LaunchpadSearchScope) -> String {
        switch scope {
        case .launchNowApps:
            return localization.text(.searchLaunchNowApps)
        case .allApplications:
            return localization.text(.searchAllApplications)
        }
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
}
