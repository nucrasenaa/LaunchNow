import AppKit

@MainActor
enum AppPanelPresenter {
    static func runModal(_ panel: NSSavePanel) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)

        let previousLevel = panel.level
        if let appWindow = AppDelegate.shared?.mainWindow {
            panel.level = NSWindow.Level(rawValue: appWindow.level.rawValue + 1)
        } else {
            panel.level = .modalPanel
        }

        defer {
            panel.level = previousLevel
        }

        panel.orderFrontRegardless()
        return panel.runModal()
    }
}
