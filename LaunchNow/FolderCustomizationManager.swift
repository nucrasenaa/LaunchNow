import AppKit
import Foundation
import SwiftUI

enum FolderColorPreset: String, CaseIterable, Identifiable, Codable {
    case automatic
    case graphite
    case blue
    case green
    case orange
    case pink
    case purple

    var id: String { rawValue }

    var tintColor: Color {
        switch self {
        case .automatic: return .secondary
        case .graphite: return .gray
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        case .purple: return .purple
        }
    }

    var nsColor: NSColor {
        switch self {
        case .automatic: return .clear
        case .graphite: return .systemGray
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .orange: return .systemOrange
        case .pink: return .systemPink
        case .purple: return .systemPurple
        }
    }
}

enum FolderBackgroundPreset: String, CaseIterable, Identifiable, Codable {
    case glass
    case tinted
    case solid
    case image
    case clear

    var id: String { rawValue }
}

enum FolderSortMode: String, CaseIterable, Identifiable {
    case nameAscending
    case nameDescending

    var id: String { rawValue }
}

struct FolderCustomization: Codable, Equatable {
    var colorPreset: FolderColorPreset
    var backgroundPreset: FolderBackgroundPreset
    var isLayoutLocked: Bool
    var backgroundImageFileName: String?
    var backgroundImageOpacity: Double

    static let `default` = FolderCustomization(
        colorPreset: .automatic,
        backgroundPreset: .glass,
        isLayoutLocked: false,
        backgroundImageFileName: nil,
        backgroundImageOpacity: 0.65
    )

    init(
        colorPreset: FolderColorPreset,
        backgroundPreset: FolderBackgroundPreset,
        isLayoutLocked: Bool,
        backgroundImageFileName: String? = nil,
        backgroundImageOpacity: Double = 0.65
    ) {
        self.colorPreset = colorPreset
        self.backgroundPreset = backgroundPreset
        self.isLayoutLocked = isLayoutLocked
        self.backgroundImageFileName = backgroundImageFileName
        self.backgroundImageOpacity = Self.clampedImageOpacity(backgroundImageOpacity)
    }

    private enum CodingKeys: String, CodingKey {
        case colorPreset
        case backgroundPreset
        case isLayoutLocked
        case backgroundImageFileName
        case backgroundImageOpacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            colorPreset: try container.decodeIfPresent(FolderColorPreset.self, forKey: .colorPreset) ?? .automatic,
            backgroundPreset: try container.decodeIfPresent(FolderBackgroundPreset.self, forKey: .backgroundPreset) ?? .glass,
            isLayoutLocked: try container.decodeIfPresent(Bool.self, forKey: .isLayoutLocked) ?? false,
            backgroundImageFileName: try container.decodeIfPresent(String.self, forKey: .backgroundImageFileName),
            backgroundImageOpacity: try container.decodeIfPresent(Double.self, forKey: .backgroundImageOpacity) ?? 0.65
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(colorPreset, forKey: .colorPreset)
        try container.encode(backgroundPreset, forKey: .backgroundPreset)
        try container.encode(isLayoutLocked, forKey: .isLayoutLocked)
        try container.encodeIfPresent(backgroundImageFileName, forKey: .backgroundImageFileName)
        try container.encode(backgroundImageOpacity, forKey: .backgroundImageOpacity)
    }

    static func clampedImageOpacity(_ value: Double) -> Double {
        min(max(value, 0.15), 1.0)
    }
}

final class FolderCustomizationManager {
    static let shared = FolderCustomizationManager()

    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var customizationsById: [String: FolderCustomization]

    private init() {
        customizationsById = (try? Self.loadCustomizations(from: Self.storageURL(fileManager: fileManager))) ?? [:]
    }

    func customization(forFolderId folderId: String) -> FolderCustomization {
        lock.lock()
        defer { lock.unlock() }
        return customizationsById[folderId] ?? .default
    }

    func setColor(_ preset: FolderColorPreset, forFolderId folderId: String) {
        update(folderId) { $0.colorPreset = preset }
    }

    func setBackground(_ preset: FolderBackgroundPreset, forFolderId folderId: String) {
        update(folderId) { $0.backgroundPreset = preset }
    }

    func setBackgroundImage(from sourceURL: URL, forFolderId folderId: String) throws {
        let image = try normalizedImage(from: sourceURL)
        let data = try pngData(from: image)
        let directory = backgroundsDirectoryURL()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = "\(encodedFileStem(for: folderId)).png"
        let destinationURL = directory.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: destinationURL, options: [.atomic])

        update(folderId) {
            $0.backgroundPreset = .image
            $0.backgroundImageFileName = fileName
            $0.backgroundImageOpacity = FolderCustomization.clampedImageOpacity($0.backgroundImageOpacity)
        }
    }

    func backgroundImage(forFolderId folderId: String) -> NSImage? {
        let customization = customization(forFolderId: folderId)
        guard let fileName = customization.backgroundImageFileName else { return nil }
        let url = backgroundsDirectoryURL().appendingPathComponent(fileName, isDirectory: false)
        return NSImage(contentsOf: url)
    }

    func hasBackgroundImage(forFolderId folderId: String) -> Bool {
        customization(forFolderId: folderId).backgroundImageFileName != nil
    }

    func setBackgroundImageOpacity(_ opacity: Double, forFolderId folderId: String) {
        update(folderId) {
            $0.backgroundImageOpacity = FolderCustomization.clampedImageOpacity(opacity)
        }
    }

    func resetBackgroundImage(forFolderId folderId: String) {
        let removedFileName: String?
        lock.lock()
        var customization = customizationsById[folderId] ?? .default
        removedFileName = customization.backgroundImageFileName
        customization.backgroundImageFileName = nil
        if customization.backgroundPreset == .image {
            customization.backgroundPreset = .glass
        }
        if customization == .default {
            customizationsById.removeValue(forKey: folderId)
        } else {
            customizationsById[folderId] = customization
        }
        let snapshot = customizationsById
        lock.unlock()

        if let removedFileName {
            try? fileManager.removeItem(at: backgroundsDirectoryURL().appendingPathComponent(removedFileName, isDirectory: false))
        }
        persist(snapshot)
    }

    func setLayoutLocked(_ isLocked: Bool, forFolderId folderId: String) {
        update(folderId) { $0.isLayoutLocked = isLocked }
    }

    func reset(folderId: String) {
        lock.lock()
        let removedFileName = customizationsById.removeValue(forKey: folderId)?.backgroundImageFileName
        let snapshot = customizationsById
        lock.unlock()
        if let removedFileName {
            try? fileManager.removeItem(at: backgroundsDirectoryURL().appendingPathComponent(removedFileName, isDirectory: false))
        }
        persist(snapshot)
    }

    func exportCustomizations() -> [String: FolderCustomization] {
        lock.lock()
        defer { lock.unlock() }
        return customizationsById
    }

    func replaceCustomizations(_ mapping: [String: FolderCustomization]) {
        lock.lock()
        customizationsById = mapping
        let snapshot = customizationsById
        lock.unlock()
        persist(snapshot)
    }

    func exportBackgroundsDirectoryURL() -> URL {
        backgroundsDirectoryURL()
    }

    func replaceBackgrounds(from sourceDirectory: URL) throws {
        let destinationDirectory = backgroundsDirectoryURL()
        if fileManager.fileExists(atPath: destinationDirectory.path) {
            try fileManager.removeItem(at: destinationDirectory)
        }
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        guard fileManager.fileExists(atPath: sourceDirectory.path) else { return }
        let files = try fileManager.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
        for file in files {
            try fileManager.copyItem(
                at: file,
                to: destinationDirectory.appendingPathComponent(file.lastPathComponent, isDirectory: false)
            )
        }
    }

    func signature(for folder: FolderInfo) -> String {
        let customization = customization(forFolderId: folder.id)
        return [
            customization.colorPreset.rawValue,
            customization.backgroundPreset.rawValue,
            customization.isLayoutLocked ? "locked" : "unlocked",
            customization.backgroundImageFileName ?? "no-image",
            String(format: "%.2f", customization.backgroundImageOpacity)
        ].joined(separator: "|")
    }

    private func update(_ folderId: String, mutate: (inout FolderCustomization) -> Void) {
        lock.lock()
        var customization = customizationsById[folderId] ?? .default
        mutate(&customization)
        if customization == .default {
            customizationsById.removeValue(forKey: folderId)
        } else {
            customizationsById[folderId] = customization
        }
        let snapshot = customizationsById
        lock.unlock()
        persist(snapshot)
    }

    private func persist(_ mapping: [String: FolderCustomization]) {
        do {
            let url = Self.storageURL(fileManager: fileManager)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try Self.encoder.encode(mapping)
            try data.write(to: url, options: [.atomic])
        } catch {
            NSSound.beep()
        }
    }

    private static func loadCustomizations(from url: URL) throws -> [String: FolderCustomization] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        return try Self.decoder.decode([String: FolderCustomization].self, from: data)
    }

    private static func storageURL(fileManager: FileManager) -> URL {
        let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return (appSupport ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support"))
            .appendingPathComponent("LaunchNow", isDirectory: true)
            .appendingPathComponent("FolderCustomizations.json", isDirectory: false)
    }

    private func backgroundsDirectoryURL() -> URL {
        let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return (appSupport ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support"))
            .appendingPathComponent("LaunchNow", isDirectory: true)
            .appendingPathComponent("FolderBackgrounds", isDirectory: true)
    }

    private func encodedFileStem(for folderId: String) -> String {
        Data(folderId.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func normalizedImage(from url: URL) throws -> NSImage {
        guard let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 else {
            throw NSError(domain: "LaunchNow.FolderCustomizationManager", code: 1)
        }
        return image
    }

    private func pngData(from image: NSImage) throws -> Data {
        let maxDimension: CGFloat = 1600
        let width = max(image.size.width, 1)
        let height = max(image.size.height, 1)
        let scale = min(1, maxDimension / max(width, height))
        let targetSize = NSSize(width: width * scale, height: height * scale)
        let rendered = NSImage(size: targetSize)
        rendered.lockFocus()
        defer { rendered.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .sourceOver, fraction: 1)

        guard let tiff = rendered.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "LaunchNow.FolderCustomizationManager", code: 2)
        }
        return data
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
