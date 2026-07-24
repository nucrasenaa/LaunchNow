import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var keyboardShortcutManager = KeyboardShortcutManager.shared

    @State private var selectedLanguage: AppLanguage
    @State private var selectedShortcut: KeyboardShortcutPreset
    @State private var shouldScanApps = true
    @State private var useFullscreenMode: Bool

    init(appStore: AppStore) {
        self.appStore = appStore
        _selectedLanguage = State(initialValue: LocalizationManager.shared.language)
        _selectedShortcut = State(initialValue: KeyboardShortcutManager.shared.preset)
        _useFullscreenMode = State(initialValue: appStore.isFullscreenMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                settingRow(title: localization.text(.onboardingLanguageTitle), systemImage: "globe") {
                    Picker("", selection: $selectedLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(localization.text(language.displayNameKey)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 210)
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

                Toggle(isOn: $shouldScanApps) {
                    settingLabel(
                        title: localization.text(.onboardingScanAppsTitle),
                        detail: localization.text(.onboardingScanAppsDescription),
                        systemImage: "magnifyingglass"
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

            HStack {
                Spacer()
                Button {
                    appStore.completeOnboarding(
                        language: selectedLanguage,
                        shortcut: selectedShortcut,
                        isFullscreen: useFullscreenMode,
                        shouldScanApps: shouldScanApps
                    )
                } label: {
                    Label(localization.text(.onboardingStart), systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 30, x: 0, y: 18)
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
