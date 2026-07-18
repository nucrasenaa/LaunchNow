import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsPaneView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var updateManager: AppUpdateManager
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var statusMessage: String?

    let currentUpdateStatusText: String
    let appVersion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(localization.text(.diagnosticsDescription))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 620, alignment: .leading)

                Button {
                    exportDebugInfo()
                } label: {
                    Label(localization.text(.exportDebugInfo), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(localization.text(.diagnosticsSummary))
                    .font(.headline)

                diagnosticsRow(title: localization.text(.versionFormat, appVersion), value: Bundle.main.bundlePath)
                diagnosticsRow(title: localization.text(.dataPath), value: DiagnosticsReportBuilder.applicationSupportURL().path)
                diagnosticsRow(title: localization.text(.updateStatus), value: currentUpdateStatusText)
                diagnosticsRow(
                    title: localization.text(.cloudBackup),
                    value: appStore.cloudBackupFolderPath ?? localization.text(.noCloudFolder)
                )
                diagnosticsRow(
                    title: localization.text(.profiles),
                    value: "\(appStore.profiles.count) / \(appStore.profileHistory.count) history"
                )
                diagnosticsRow(
                    title: localization.text(.gridLayout),
                    value: "\(appStore.gridColumns)x\(appStore.gridRows), \(appStore.items.count) items"
                )
            }
            .padding(12)
            .frame(maxWidth: 620, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
    }

    private func diagnosticsRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .frame(width: 160, alignment: .leading)
            Text(value)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func exportDebugInfo() {
        let panel = NSSavePanel()
        panel.title = localization.text(.exportDebugInfo)
        panel.nameFieldStringValue = DiagnosticsReportBuilder.suggestedFileName()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard AppPanelPresenter.runModal(panel) == .OK, let url = panel.url else { return }

        do {
            let report = DiagnosticsReportBuilder.makeReport(appStore: appStore, updateManager: updateManager)
            try report.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = localization.text(.debugInfoExported)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            statusMessage = localization.text(.debugInfoExportFailed, error.localizedDescription)
        }
    }
}
