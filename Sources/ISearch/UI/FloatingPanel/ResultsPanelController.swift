import Foundation
import AppKit
import SwiftUI

/// Floating panel subclass that can become key to receive keyboard navigation and shortcuts.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Window controller managing the floating results panel with adaptive positioning near the selection.
@MainActor
public final class ResultsPanelController: NSObject {
    public static let shared = ResultsPanelController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var localKeyMonitor: Any?

    private override init() {
        super.init()
    }

    /// Shows or updates the floating results panel near the target selection rect.
    public func show<Content: View>(
        content: Content,
        near selectionRect: CGRect,
        on targetScreen: NSScreen,
        panelSize: CGSize = CGSize(width: 520, height: 310)
    ) {
        let screenVisibleFrame = targetScreen.visibleFrame

        // Calculate horizontal placement centered on selection, clamped to visible screen
        var panelX = selectionRect.midX - (panelSize.width / 2)
        panelX = max(screenVisibleFrame.minX + 16, min(screenVisibleFrame.maxX - panelSize.width - 16, panelX))

        // Prefer placing below the selection, fallback to above if near screen bottom
        var panelY = selectionRect.minY - panelSize.height - 12
        if panelY < screenVisibleFrame.minY + 16 {
            panelY = selectionRect.maxY + 12
        }

        // Final safety clamp within visible display bounds
        panelY = max(screenVisibleFrame.minY + 16, min(screenVisibleFrame.maxY - panelSize.height - 16, panelY))

        let panelRect = CGRect(x: panelX, y: panelY, width: panelSize.width, height: panelSize.height)

        if let existingPanel = self.panel {
            existingPanel.setFrame(panelRect, display: true, animate: false)
            let host = NSHostingView(rootView: AnyView(content))
            existingPanel.contentView = host
            self.hostingView = host
            existingPanel.orderFrontRegardless()
            existingPanel.makeKey()
            return
        }

        let newPanel = KeyablePanel(
            contentRect: panelRect,
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newPanel.level = .floating
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.isReleasedWhenClosed = false
        newPanel.minSize = NSSize(width: 420, height: 260)
        newPanel.maxSize = NSSize(width: 800, height: 900)
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let host = NSHostingView(rootView: AnyView(content))
        newPanel.contentView = host

        NSApp.activate(ignoringOtherApps: true)
        newPanel.makeKeyAndOrderFront(nil)

        self.panel = newPanel
        self.hostingView = host

        // Install key monitor to dismiss on Escape (keyCode 53)
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // Escape
                    self?.dismiss()
                    AppState.shared.dismissPanel()
                    return nil
                }
                return event
            }
        }
    }

    /// Updates the view content inside the current panel.
    public func updateContent<Content: View>(_ content: Content) {
        if let host = hostingView {
            host.rootView = AnyView(content)
        }
    }

    /// Dynamically resizes the panel height to fit state transitions (e.g. review -> response).
    public func updatePanelHeight(_ newHeight: CGFloat, animated: Bool = true) {
        guard let panel = self.panel, let screen = panel.screen ?? NSScreen.main else { return }
        var currentFrame = panel.frame
        let heightDiff = newHeight - currentFrame.size.height
        currentFrame.origin.y -= heightDiff
        currentFrame.size.height = newHeight

        let visible = screen.visibleFrame
        if currentFrame.minY < visible.minY + 16 {
            currentFrame.origin.y = visible.minY + 16
        }
        if currentFrame.maxY > visible.maxY - 16 {
            currentFrame.origin.y = visible.maxY - 16 - currentFrame.size.height
        }

        panel.setFrame(currentFrame, display: true, animate: animated)
        panel.invalidateShadow()
    }

    /// Dismisses and closes the floating results panel.
    public func dismiss() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        NSApp.hide(nil)
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
