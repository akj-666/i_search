import Foundation
import AppKit
import CoreGraphics

/// Custom NSView providing an interactive dimmed overlay with resizable selection, handles, dimension badge, and hints.
public final class SelectionOverlayView: NSView {
    public var onConfirm: ((CGRect) -> Void)?
    public var onCancel: (() -> Void)?
    public var selectionShape: SelectionShape = .rectangle

    public private(set) var selectionRect: CGRect = .zero {
        didSet {
            needsDisplay = true
        }
    }

    private enum DragMode {
        case creating(startPoint: CGPoint)
        case resizing(handle: SelectionHandle, initialRect: CGRect, startPoint: CGPoint)
        case moving(initialRect: CGRect, startPoint: CGPoint)
    }

    private var currentDragMode: DragMode?
    private var trackingAreaRef: NSTrackingArea?

    override public var acceptsFirstResponder: Bool { true }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingAreas()
        window?.makeFirstResponder(self)
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef = trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .cursorUpdate, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
        self.trackingAreaRef = tracking
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw dimmed scrim over entire screen
        context.saveGState()
        context.setFillColor(NSColor(white: 0.0, alpha: 0.45).cgColor)
        context.fill(bounds)

        // 2. Clear cutout for selected region
        if !selectionRect.isEmpty {
            context.setBlendMode(.clear)
            if selectionShape == .circle {
                context.fillEllipse(in: selectionRect)
            } else {
                context.fill(selectionRect)
            }
            context.setBlendMode(.normal)

            // 3. Draw vibrant selection outline
            context.setStrokeColor(NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0).cgColor)
            context.setLineWidth(2.0)
            if selectionShape == .circle {
                context.strokeEllipse(in: selectionRect)
            } else {
                context.stroke(selectionRect.insetBy(dx: 1, dy: 1))
            }

            // 4. Draw selection handles if not currently creating a new box
            if selectionShape == .rectangle {
                drawHandles(in: context, rect: selectionRect)
            }

            // 5. Draw dimensions badge
            drawDimensionsBadge(in: context, for: selectionRect)
        }

        // 6. Draw hint pill at top center of screen
        drawTopHintPill(in: context)

        context.restoreGState()
    }

    private func drawHandles(in context: CGContext, rect: CGRect) {
        let handleRadius: CGFloat = 4.0
        let points = [
            CGPoint(x: rect.minX, y: rect.maxY), // Top-left
            CGPoint(x: rect.midX, y: rect.maxY), // Top
            CGPoint(x: rect.maxX, y: rect.maxY), // Top-right
            CGPoint(x: rect.maxX, y: rect.midY), // Right
            CGPoint(x: rect.maxX, y: rect.minY), // Bottom-right
            CGPoint(x: rect.midX, y: rect.minY), // Bottom
            CGPoint(x: rect.minX, y: rect.minY), // Bottom-left
            CGPoint(x: rect.minX, y: rect.midY)  // Left
        ]

        context.setFillColor(NSColor.white.cgColor)
        context.setStrokeColor(NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0).cgColor)
        context.setLineWidth(1.5)

        for p in points {
            let handleRect = CGRect(x: p.x - handleRadius, y: p.y - handleRadius, width: handleRadius * 2, height: handleRadius * 2)
            context.fillEllipse(in: handleRect)
            context.strokeEllipse(in: handleRect)
        }
    }

    private func drawDimensionsBadge(in context: CGContext, for rect: CGRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height)) pt"
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let textSize = (text as NSString).size(withAttributes: attrs)
        let paddingH: CGFloat = 8
        let paddingV: CGFloat = 4
        let badgeWidth = textSize.width + (paddingH * 2)
        let badgeHeight = textSize.height + (paddingV * 2)

        var badgeY = rect.maxY + 8
        if badgeY + badgeHeight > bounds.height - 40 {
            badgeY = max(8, rect.minY - badgeHeight - 8)
        }
        let badgeX = max(8, min(bounds.width - badgeWidth - 8, rect.midX - (badgeWidth / 2)))
        let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)

        // Draw pill background
        let pillPath = NSBezierPath(roundedRect: badgeRect, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2)
        NSColor(white: 0.1, alpha: 0.85).setFill()
        pillPath.fill()

        // Draw pill border
        NSColor(white: 1.0, alpha: 0.2).setStroke()
        pillPath.lineWidth = 0.5
        pillPath.stroke()

        // Draw text
        let textPoint = CGPoint(x: badgeRect.origin.x + paddingH, y: badgeRect.origin.y + paddingV - 0.5)
        (text as NSString).draw(at: textPoint, withAttributes: attrs)
    }

    private func drawTopHintPill(in context: CGContext) {
        let hintText = "Drag to select • Return or Double-Click to confirm • Esc to cancel"
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let textSize = (hintText as NSString).size(withAttributes: attrs)
        let paddingH: CGFloat = 16
        let paddingV: CGFloat = 8
        let pillWidth = textSize.width + (paddingH * 2)
        let pillHeight = textSize.height + (paddingV * 2)

        let pillX = (bounds.width - pillWidth) / 2
        let pillY = bounds.height - pillHeight - 20
        let pillRect = CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)

        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 10, yRadius: 10)
        NSColor(white: 0.12, alpha: 0.90).setFill()
        pillPath.fill()

        NSColor(white: 1.0, alpha: 0.25).setStroke()
        pillPath.lineWidth = 1.0
        pillPath.stroke()

        let textPoint = CGPoint(x: pillRect.origin.x + paddingH, y: pillRect.origin.y + paddingV - 0.5)
        (hintText as NSString).draw(at: textPoint, withAttributes: attrs)
    }

    // MARK: - Mouse Events

    public override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let handle = SelectionGeometry.hitTest(point: loc, in: selectionRect)
        handle.cursor.set()
    }

    public override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        // Double click confirms selection immediately
        if event.clickCount == 2 && selectionRect.contains(loc) {
            confirmSelection()
            return
        }

        let handle = SelectionGeometry.hitTest(point: loc, in: selectionRect)

        if handle == .inside {
            currentDragMode = .moving(initialRect: selectionRect, startPoint: loc)
            NSCursor.closedHand.set()
        } else if handle != .none {
            currentDragMode = .resizing(handle: handle, initialRect: selectionRect, startPoint: loc)
            handle.cursor.set()
        } else {
            // New selection
            currentDragMode = .creating(startPoint: loc)
            selectionRect = CGRect(origin: loc, size: .zero)
            NSCursor.crosshair.set()
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let mode = currentDragMode else { return }
        let currentLoc = convert(event.locationInWindow, from: nil)

        switch mode {
        case .creating(let startPoint):
            selectionRect = SelectionGeometry.normalizeRect(from: startPoint, to: currentLoc)
        case .resizing(let handle, _, _):
            let deltaX = event.deltaX
            let deltaY = -event.deltaY // AppKit Y coordinates
            selectionRect = SelectionGeometry.resize(rect: selectionRect, handle: handle, deltaX: deltaX, deltaY: deltaY)
            handle.cursor.set()
        case .moving:
            let deltaX = event.deltaX
            let deltaY = -event.deltaY
            selectionRect = selectionRect.offsetBy(dx: deltaX, dy: deltaY)
            NSCursor.closedHand.set()
        }
    }

    public override func mouseUp(with event: NSEvent) {
        currentDragMode = nil
        let loc = convert(event.locationInWindow, from: nil)
        SelectionGeometry.hitTest(point: loc, in: selectionRect).cursor.set()

        // If selection is too tiny (accidental click), reset
        if selectionRect.width < 10 || selectionRect.height < 10 {
            selectionRect = .zero
        }
    }

    // MARK: - Keyboard Events

    public override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape
            onCancel?()
        case 36, 49: // Return or Space
            confirmSelection()
        default:
            super.keyDown(with: event)
        }
    }

    private func confirmSelection() {
        guard selectionRect.width >= 10 && selectionRect.height >= 10 else {
            onCancel?()
            return
        }
        onConfirm?(selectionRect)
    }
}
