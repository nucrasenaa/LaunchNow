import AppKit
import Foundation

final class CustomAppIconManager {
    static let shared = CustomAppIconManager()

    private static let defaultsKey = "customAppIconFilesByPath"
    private let fileManager = FileManager.default
    private var iconFilesByPath: [String: String]
    private let lock = NSLock()

    private init() {
        iconFilesByPath = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
    }

    func icon(forAppURL appURL: URL) -> NSImage {
        if let customIcon = customIcon(forAppPath: appURL.path) {
            return customIcon
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    func hasCustomIcon(forAppPath appPath: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return iconFilesByPath[appPath] != nil
    }

    func customIcon(forAppPath appPath: String) -> NSImage? {
        lock.lock()
        let fileName = iconFilesByPath[appPath]
        lock.unlock()

        guard let fileName else { return nil }
        let url = iconsDirectoryURL().appendingPathComponent(fileName, isDirectory: false)
        return NSImage(contentsOf: url)
    }

    func setCustomIcon(from sourceURL: URL, forAppPath appPath: String) throws {
        let image = try normalizedImage(from: sourceURL)
        let data = try pngData(from: image)
        let directory = iconsDirectoryURL()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = "\(encodedFileStem(for: appPath)).png"
        let destinationURL = directory.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: destinationURL, options: [.atomic])

        lock.lock()
        iconFilesByPath[appPath] = fileName
        let snapshot = iconFilesByPath
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: Self.defaultsKey)
    }

    func resetCustomIcon(forAppPath appPath: String) {
        lock.lock()
        let fileName = iconFilesByPath.removeValue(forKey: appPath)
        let snapshot = iconFilesByPath
        lock.unlock()

        UserDefaults.standard.set(snapshot, forKey: Self.defaultsKey)

        if let fileName {
            let url = iconsDirectoryURL().appendingPathComponent(fileName, isDirectory: false)
            try? fileManager.removeItem(at: url)
        }
    }

    func exportIconFiles() -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return iconFilesByPath
    }

    func exportIconsDirectoryURL() -> URL {
        iconsDirectoryURL()
    }

    func replaceIcons(with mapping: [String: String], from sourceDirectory: URL) throws {
        let destinationDirectory = iconsDirectoryURL()
        if fileManager.fileExists(atPath: destinationDirectory.path) {
            try fileManager.removeItem(at: destinationDirectory)
        }
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: sourceDirectory.path) {
            let files = try fileManager.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.copyItem(
                    at: file,
                    to: destinationDirectory.appendingPathComponent(file.lastPathComponent, isDirectory: false)
                )
            }
        }

        lock.lock()
        iconFilesByPath = mapping
        let snapshot = iconFilesByPath
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: Self.defaultsKey)
    }

    private func iconsDirectoryURL() -> URL {
        let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return (appSupport ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support"))
            .appendingPathComponent("LaunchNow", isDirectory: true)
            .appendingPathComponent("CustomIcons", isDirectory: true)
    }

    private func encodedFileStem(for appPath: String) -> String {
        Data(appPath.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func normalizedImage(from url: URL) throws -> NSImage {
        guard let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 else {
            throw NSError(domain: "LaunchNow.CustomAppIconManager", code: 1)
        }
        return image
    }

    private func pngData(from image: NSImage) throws -> Data {
        let targetSize = NSSize(width: 512, height: 512)
        let rendered = NSImage(size: targetSize)
        rendered.lockFocus()
        defer { rendered.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: targetSize).fill()
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .sourceOver, fraction: 1)

        guard let tiff = rendered.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "LaunchNow.CustomAppIconManager", code: 2)
        }
        return data
    }
}
