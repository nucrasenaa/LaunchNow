import AppKit
import UniformTypeIdentifiers

enum AppIconProvider {
    static let placeholderIcon: NSImage = {
        let icon = NSWorkspace.shared.icon(for: .applicationBundle)
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }()

    static func displayIcon(for app: AppInfo) -> NSImage {
        if let cachedIcon = AppCacheManager.shared.getCachedIcon(for: app.url.path),
           cachedIcon.size.width > 0,
           cachedIcon.size.height > 0 {
            return cachedIcon
        }
        if app.hasLoadedIcon, app.icon.size.width > 0, app.icon.size.height > 0 {
            return app.icon
        }
        return placeholderIcon
    }
}
