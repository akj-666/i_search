import Foundation
import AppKit
import SwiftUI

/// Window controller managing the floating results panel with adaptive positioning near the selection.
@MainActor
public final class ResultsPanelController: NSObject {
    public static let shared = ResultsPanelController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    private override init() {
        super.init()
    }

    /// Shows or updates the floating results panel near the target selection rect.
    public func show<Content: View>(
        content: Content,
        near selectionRect: CGRect,
        on targetScreen: NSScreen,
        panelSize: CGSize = CGSize(width: 480, height: 340)
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
            existingPanel.contentView = NSHostingView(rootView: AnyView(content))
            existingPanel.orderFrontRegardless()
            return
        }

        let newPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel, .fullSizeContentView],
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
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let host = NSHostingView(rootView: AnyView(content))
        newPanel.contentView = host
        newPanel.orderFrontRegardless()

        self.panel = newPanel
        self.hostingView = host
    }

    /// Updates the view content inside the current panel.
    public func updateContent<Content: View>(_ content: Content) {
        if let host = hostingView {
            host.rootView = AnyView(content)
        }
    }

    /// Dismisses and closes the floating results panel.
    public func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
