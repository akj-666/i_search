import Foundation
import AppKit

/// Borderless full-screen window that can accept key status and keyboard events.
final class SelectionOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Controller managing the full-screen selection overlay window and user interaction.
@MainActor
public final class SelectionOverlayController: NSObject {
    public static let shared = SelectionOverlayController()

    public var onSelectionConfirmed: ((CGRect, NSScreen) -> Void)?
    public var onSelectionCanceled: (() -> Void)?

    private var overlayWindows: [NSWindow] = []
    private var activeScreen: NSScreen?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    private override init() {
        super.init()
    }

    /// Presents the dimmed selection overlay on the display where the cursor is located.
    public func startSelection(shape: SelectionShape = .rectangle) {
        dismiss()

        let mouseLoc = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = targetScreen else {
            NSLog("[SelectionOverlayController] No screen available.")
            return
        }

        self.activeScreen = screen

        let window = SelectionOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let overlayView = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        overlayView.selectionShape = shape

        overlayView.onConfirm = { [weak self, weak window] localRect in
            guard let self = self, let screen = self.activeScreen else { return }
            let globalX = screen.frame.origin.x + localRect.origin.x
            let globalY = screen.frame.origin.y + localRect.origin.y
            let globalRect = CGRect(x: globalX, y: globalY, width: localRect.width, height: localRect.height)

            // Hide overlay window immediately before capturing
            window?.orderOut(nil)
            self.dismiss()

            // Small delay to ensure display server refreshes before capture
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.onSelectionConfirmed?(globalRect, screen)
            }
        }

        overlayView.onCancel = { [weak self] in
            self?.dismiss()
            self?.onSelectionCanceled?()
        }

        window.contentView = overlayView

        // Activate app and make window key
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(overlayView)
        overlayWindows.append(window)

        // Install local monitor to catch Escape (keyCode 53)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                self?.onSelectionCanceled?()
                return nil // Consume event
            }
            return event
        }

        // Install global monitor to catch Escape even if another window briefly holds focus
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    self?.dismiss()
                    self?.onSelectionCanceled?()
                }
            }
        }

        NSCursor.crosshair.set()
    }

    /// Dismisses all active overlay windows and restores cursor.
    public func dismiss() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }

        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        activeScreen = nil
        NSCursor.arrow.set()
    }
}
