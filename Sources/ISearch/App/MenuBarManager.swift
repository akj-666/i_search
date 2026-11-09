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
            button.toolTip = "i search (⌘⇧Space)"
        }

        buildMenu()
    }

    /// Rebuilds the context menu.
    public func buildMenu() {
        let menu = NSMenu()

        // App Title Item
        let titleItem = NSMenuItem(title: "i search", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "i search",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor
            ]
        )
        menu.addItem(titleItem)

        // Capture Action
        let shortcutString = GlobalShortcutManager.shared.currentCombo.displayString
        let captureItem = NSMenuItem(
            title: "Capture Selection (\(shortcutString))",
            action: #selector(captureClicked),
            keyEquivalent: ""
        )
        captureItem.target = self
        captureItem.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Capture")
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
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw a refined viewfinder circle icon
        let bounds = NSRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)

        // Outer circle
        let circlePath = NSBezierPath(ovalIn: bounds)
        circlePath.lineWidth = 1.6
        NSColor.black.setStroke()
        circlePath.stroke()

        // Center dot / sparkle
        let centerPoint = NSPoint(x: size.width / 2, y: size.height / 2)
        let dotSize: CGFloat = 3.2
        let dotRect = NSRect(
            x: centerPoint.x - (dotSize / 2),
            y: centerPoint.y - (dotSize / 2),
            width: dotSize,
            height: dotSize
        )
        let dotPath = NSBezierPath(ovalIn: dotRect)
        NSColor.black.setFill()
        dotPath.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
