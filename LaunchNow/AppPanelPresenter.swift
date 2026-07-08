import AppKit

@MainActor
enum AppPanelPresenter {
    static func runModal(_ panel: NSSavePanel) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)

        let previousLevel = panel.level
        AppDelegate.shared?.beginSystemPanelPresentation()
        panel.level = .modalPanel

        defer {
            panel.level = previousLevel
            AppDelegate.shared?.endSystemPanelPresentation()
        }

        panel.orderFrontRegardless()
        return panel.runModal()
    }
}
