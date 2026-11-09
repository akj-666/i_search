import Foundation
import AppKit
import SwiftUI

/// Window controller for the Onboarding / Welcome window.
@MainActor
public final class WelcomeWindowController: NSObject {
    public static let shared = WelcomeWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    /// Presents the Welcome window.
    public func show(onTestShortcut: @escaping () -> Void, onComplete: @escaping () -> Void) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let welcomeView = WelcomeView(
            onTestShortcut: { [weak self] in
                self?.window?.orderOut(nil)
                onTestShortcut()
            },
            onComplete: { [weak self] in
                self?.window?.close()
                self?.window = nil
                onComplete()
            }
        )

        let newWindow = DismissableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "Welcome to i search"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.contentView = NSHostingView(rootView: welcomeView)

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        window?.close()
        window = nil
    }
}
