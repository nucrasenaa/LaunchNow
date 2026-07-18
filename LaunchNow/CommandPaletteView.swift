import AppKit
import SwiftUI

struct CommandPaletteEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case app(AppInfo)
        case folder(FolderInfo)
        case file(URL)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .app(let app):
            return "app-\(app.url.path)"
        case .folder(let folder):
            return "folder-\(folder.id)"
        case .file(let url):
            return "file-\(url.path)"
        }
    }

    var title: String {
        switch kind {
        case .app(let app):
            return app.name
        case .folder(let folder):
            return folder.name
        case .file(let url):
            return url.lastPathComponent
        }
    }

    var subtitle: String {
        switch kind {
        case .app(let app):
            return app.url.path
        case .folder(let folder):
            return "\(folder.apps.count) apps"
        case .file(let url):
            return url.path
        }
    }

    var icon: NSImage {
        switch kind {
        case .app(let app):
            return app.icon
        case .folder(let folder):
            return folder.icon(of: 36)
        case .file(let url):
            return NSWorkspace.shared.icon(forFile: url.path)
        }
    }

    var supportsEditActions: Bool {
        switch kind {
        case .app, .folder:
            return true
        case .file:
            return false
        }
    }
}

struct CommandPaletteView: View {
    @ObservedObject private var localization = LocalizationManager.shared

    let entries: [CommandPaletteEntry]
    let onOpen: (CommandPaletteEntry) -> Void
    let onShowInFinder: (CommandPaletteEntry) -> Void
    let onRename: (CommandPaletteEntry) -> Void
    let onChangeIcon: (CommandPaletteEntry) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var spotlightEntries: [CommandPaletteEntry] = []
    @State private var isSearchingSpotlight = false
    @FocusState private var isSearchFocused: Bool

    private var filteredEntries: [CommandPaletteEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        var result = entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(trimmed) ||
            entry.subtitle.localizedCaseInsensitiveContains(trimmed)
        }
        let existingIds = Set(result.map(\.id))
        result.append(contentsOf: spotlightEntries.filter { !existingIds.contains($0.id) })
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .foregroundStyle(.secondary)
                TextField(localization.text(.commandPalettePlaceholder), text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onChange(of: query) { _, _ in clampSelection() }
            }
            .padding(16)

            Divider()

            if filteredEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: isSearchingSpotlight ? "clock" : "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(isSearchingSpotlight ? localization.text(.commandPaletteSearchingFiles) : localization.text(.commandPaletteEmpty))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                                commandRow(entry, isSelected: selectedIndex == index)
                                    .id(entry.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedIndex = index
                                        onOpen(entry)
                                    }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 380)
                    .onChange(of: selectedIndex) { _, newValue in
                        guard filteredEntries.indices.contains(newValue) else { return }
                        proxy.scrollTo(filteredEntries[newValue].id, anchor: .center)
                    }
                }
            }

            Divider()

            HStack {
                Text(localization.text(.commandPaletteShortcutHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(localization.text(.cancel)) {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
        }
        .frame(width: 680)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 18)
        .onAppear {
            isSearchFocused = true
            clampSelection()
        }
        .task(id: query) {
            await searchSpotlightFiles(for: query)
        }
        .onExitCommand {
            onDismiss()
        }
        .onMoveCommand { direction in
            switch direction {
            case .up:
                moveSelection(by: -1)
            case .down:
                moveSelection(by: 1)
            default:
                break
            }
        }
        .onSubmit {
            openSelectedEntry()
        }
    }

    private func commandRow(_ entry: CommandPaletteEntry, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: entry.icon)
                .resizable()
                .frame(width: 34, height: 34)
                .cornerRadius(7)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    onOpen(entry)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .help(localization.text(.open))

                Button {
                    onShowInFinder(entry)
                } label: {
                    Image(systemName: "folder")
                }
                .help(localization.text(.showInFinder))

                Button {
                    onRename(entry)
                } label: {
                    Image(systemName: "pencil")
                }
                .help(localization.text(.renameApp))
                .disabled(!entry.supportsEditActions)

                Button {
                    onChangeIcon(entry)
                } label: {
                    Image(systemName: "photo")
                }
                .help(localization.text(.changeIcon))
                .disabled(!entry.supportsEditActions)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        )
    }

    private func moveSelection(by offset: Int) {
        guard !filteredEntries.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = max(0, min(selectedIndex + offset, filteredEntries.count - 1))
    }

    private func clampSelection() {
        guard !filteredEntries.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(selectedIndex, filteredEntries.count - 1)
    }

    private func openSelectedEntry() {
        guard filteredEntries.indices.contains(selectedIndex) else { return }
        onOpen(filteredEntries[selectedIndex])
    }

    @MainActor
    private func searchSpotlightFiles(for rawQuery: String) async {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            spotlightEntries = []
            isSearchingSpotlight = false
            return
        }

        isSearchingSpotlight = true
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }

        let paths = await SpotlightFileSearcher.search(query: trimmed, limit: 18)
        guard !Task.isCancelled else { return }
        spotlightEntries = paths.map { CommandPaletteEntry(kind: .file($0)) }
        isSearchingSpotlight = false
        clampSelection()
    }
}

private enum SpotlightFileSearcher {
    static func search(query: String, limit: Int) async -> [URL] {
        await Task.detached(priority: .utility) {
            let escaped = query.replacingOccurrences(of: "'", with: "\\'")
            let predicate = "kMDItemFSName == '*\(escaped)*'cd"
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
            process.arguments = ["-onlyin", NSHomeDirectory(), predicate]
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return [] }
                let output = String(data: data, encoding: .utf8) ?? ""
                return output
                    .split(separator: "\n")
                    .prefix(limit)
                    .map { URL(fileURLWithPath: String($0)) }
            } catch {
                return []
            }
        }.value
    }
}
