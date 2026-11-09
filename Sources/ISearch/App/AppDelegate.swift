import Foundation
import AppKit

/// Application delegate handling initialization, menu bar setup, global shortcut binding, and onboarding.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure menu bar item
        MenuBarManager.shared.setup()

        // Bind global shortcut handler
        GlobalShortcutManager.shared.setHandler {
            AppState.shared.startSelection()
        }
        GlobalShortcutManager.shared.register()

        // Check screen capture permission status and request if missing
        if !PermissionManager.shared.checkPermission() {
            PermissionManager.shared.requestPermission()
        }

        // Show welcome onboarding on first run
        AppState.shared.checkAndShowOnboarding()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppState.shared.startSelection()
        }
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
        GlobalShortcutManager.shared.unregister()
    }
}
