import SwiftUI

@main
struct MacSideDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Keep an empty Settings scene so AppKit has a settings host, but strip
        // the system Preferences / Cmd+, command. Opening Settings is menu-bar only.
        Settings {
            EmptyView()
                .frame(width: 0, height: 0)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {}
        }
    }
}
