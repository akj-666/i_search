import Foundation
import AppKit

/// Controller managing the full-screen selection overlay window and user interaction.
@MainActor
public final class SelectionOverlayController: NSObject {
    public static let shared = SelectionOverlayController()

    public var onSelectionConfirmed: ((CGRect, NSScreen) -> Void)?
    public var onSelectionCanceled: (() -> Void)?

    private var overlayWindows: [NSWindow] = []
    private var activeScreen: NSScreen?

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

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
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
        window.orderFrontRegardless()
        window.makeKey()
        overlayWindows.append(window)

        NSCursor.crosshair.set()
    }

    /// Dismisses all active overlay windows and restores cursor.
    public func dismiss() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        activeScreen = nil
        NSCursor.arrow.set()
    }
}
