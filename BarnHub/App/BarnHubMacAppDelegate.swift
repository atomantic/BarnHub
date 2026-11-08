import SwiftUI

#if os(macOS)
@MainActor
final class BarnHubMacAppDelegate: NSObject, NSApplicationDelegate {
    static var reopenWindow: (() -> Void)?

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            DispatchQueue.main.async { Self.showOrCreateMainWindow() }
        }
        return true
    }

    static func showOrCreateMainWindow() {
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        reopenWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif
