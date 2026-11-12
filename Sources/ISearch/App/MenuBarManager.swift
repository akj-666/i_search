import Foundation
import AppKit

/// Configures and manages the macOS menu bar status item and context menu.
@MainActor
public final class MenuBarManager: NSObject {
    public static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?

    private override init() {
        super.init()
    }

    /// Sets up the status item in the macOS system menu bar.
    public func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item

        if let button = item.button {
            button.image = createMenuBarIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "i search (\(GlobalShortcutManager.shared.currentCombo.displayString))"
        }

        buildMenu()
    }

    /// Rebuilds the context menu.
    public func buildMenu() {
        let menu = NSMenu()

        // App Title Item
        let titleItem = NSMenuItem(title: "i search", action: nil, keyEquivalent: "")
        titleItem.image = AppBranding.appIcon(size: 16)
        titleItem.attributedTitle = NSAttributedString(
            string: "  i search",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor
            ]
        )
        menu.addItem(titleItem)

        // Capture Action
        let shortcutString = GlobalShortcutManager.shared.currentCombo.displayString
        statusItem?.button?.toolTip = "i search (\(shortcutString))"
        let captureItem = NSMenuItem(
            title: "Capture Selection (\(shortcutString))",
            action: #selector(captureClicked),
            keyEquivalent: ""
        )
        captureItem.target = self
        captureItem.image = AppBranding.menuBarIcon()
        menu.addItem(captureItem)

        menu.addItem(NSMenuItem.separator())

        // Check Permissions
        let permItem = NSMenuItem(
            title: "Check Permissions...",
            action: #selector(checkPermissionsClicked),
            keyEquivalent: ""
        )
        permItem.target = self
        permItem.image = NSImage(systemSymbolName: "checkmark.shield", accessibilityDescription: "Permissions")
        menu.addItem(permItem)

        // Welcome / Guide
        let welcomeItem = NSMenuItem(
            title: "Welcome & Quick Guide...",
            action: #selector(welcomeClicked),
            keyEquivalent: ""
        )
        welcomeItem.target = self
        welcomeItem.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Guide")
        menu.addItem(welcomeItem)

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(settingsClicked),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit i search",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    @objc private func captureClicked() {
        AppState.shared.startSelection()
    }

    @objc private func checkPermissionsClicked() {
        PermissionManager.shared.checkPermission()
        AppState.shared.openSettings()
    }

    @objc private func welcomeClicked() {
        AppState.shared.showWelcome()
    }

    @objc private func settingsClicked() {
        AppState.shared.openSettings()
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }

    // MARK: - Icon Generation

    private func createMenuBarIcon() -> NSImage {
        return AppBranding.menuBarIcon()
    }
}
