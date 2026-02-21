import AppKit
import SwiftUI
import CatCompanionCore

final class AssistantChatWindowController {
    private let window: NSWindow

    init(assistantRuntime: AssistantRuntime) {
        let rootView = AssistantChatView(assistantRuntime: assistantRuntime)
        let hosting = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 260, y: 180, width: 540, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppStrings.text(.assistantChatWindowTitle)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.setFrameAutosaveName("AssistantChatWindow")
        self.window = window
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
