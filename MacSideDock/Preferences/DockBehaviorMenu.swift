import AppKit
import SwiftUI

enum DockSettingsWindow {
    private static var window: NSWindow?

    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: PreferencesView(store: .shared))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppBrand.name
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("SIDEDOCK.Settings")
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}

/// Right-click on the dock glass — same family as the system Dock menu.
struct DockBehaviorMenuItems: View {
    var store: DockConfigStore

    var body: some View {
        Button(store.config.shouldAutoHide ? "Turn Hiding Off" : "Turn Hiding On") {
            store.update { $0.toggleHiding() }
        }
        Button(store.config.isMagnificationOn ? "Turn Magnification Off" : "Turn Magnification On") {
            store.update { $0.toggleMagnification() }
        }
        Menu("Position on Screen") {
            Button("Left") {
                store.update { $0.edge = .left }
            }
            Button("Right") {
                store.update { $0.edge = .right }
            }
        }
    }
}
