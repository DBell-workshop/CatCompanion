import AppKit
import SwiftUI
import CatCompanionCore

final class PetWindowController {
    private let window: NSPanel

    init(
        settingsStore: SettingsStore,
        reminderEngine: ReminderEngine,
        assistantRuntime: AssistantRuntime
    ) {
        let contentView = PetRootView(
            reminderEngine: reminderEngine,
            settingsStore: settingsStore,
            assistantRuntime: assistantRuntime
        )
        let hosting = NSHostingView(rootView: contentView)

        let panel = NSPanel(
            contentRect: NSRect(x: 200, y: 200, width: 240, height: 280),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hidesOnDeactivate = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView = hosting

        self.window = panel
        setAlwaysOnTop(settingsStore.settings.petAlwaysOnTop)
    }

    func show() {
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        window.level = enabled ? .floating : .normal
    }
}
