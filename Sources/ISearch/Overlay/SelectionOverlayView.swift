import Foundation
import AppKit
import CoreGraphics

/// Custom NSView providing an interactive dimmed overlay with circling, highlighting, and tap-to-select support.
public final class SelectionOverlayView: NSView {
    public var onConfirm: ((CGRect) -> Void)?
    public var onCancel: (() -> Void)?
    public var selectionShape: SelectionShape = .rectangle

    public private(set) var selectionRect: CGRect = .zero {
        didSet {
            needsDisplay = true
        }
    }

    private var gesturePoints: [CGPoint] = []
    private var isDrawing: Bool = false
    private var initialMouseDownPoint: CGPoint = .zero
    private var isTapSelection: Bool = false

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
        context.setFillColor(NSColor(white: 0.0, alpha: 0.40).cgColor)
        context.fill(bounds)

        // 2. Clear cutout for selected region
        if !selectionRect.isEmpty {
            context.setBlendMode(.clear)
            let cornerRadius: CGFloat = isTapSelection ? 14 : 10
            let cutoutPath = NSBezierPath(roundedRect: selectionRect, xRadius: cornerRadius, yRadius: cornerRadius)
            cutoutPath.fill()
            context.setBlendMode(.normal)

            // 3. Draw vibrant selection outline
            context.setStrokeColor(NSColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 0.95).cgColor)
            context.setLineWidth(2.5)
            let borderPath = NSBezierPath(roundedRect: selectionRect.insetBy(dx: 1, dy: 1), xRadius: cornerRadius, yRadius: cornerRadius)
            borderPath.stroke()

            // 4. Live freehand gesture stroke tracing the circle or highlight
            if isDrawing && gesturePoints.count > 1 {
                context.saveGState()
                context.setStrokeColor(NSColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 0.85).cgColor)
                context.setLineWidth(4.0)
                context.setLineCap(.round)
                context.setLineJoin(.round)

                let path = CGMutablePath()
                path.move(to: gesturePoints[0])
                for pt in gesturePoints.dropFirst() {
                    path.addLine(to: pt)
                }
                context.addPath(path)
                context.strokePath()
                context.restoreGState()
            }

            // 5. Draw dimensions / mode badge
            drawDimensionsBadge(in: context, for: selectionRect)
        }

        // 6. Draw hint pill at top center of screen
        drawTopHintPill(in: context)

        context.restoreGState()
    }

    private func drawDimensionsBadge(in context: CGContext, for rect: CGRect) {
        let text = isTapSelection ? "Tapped Item" : "\(Int(rect.width)) × \(Int(rect.height)) pt"
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
        let hintText = "Circle, highlight, or tap anything on screen • Esc to cancel"
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
        NSCursor.crosshair.set()
    }

    public override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        initialMouseDownPoint = loc
        gesturePoints = [loc]
        isDrawing = true
        isTapSelection = false
        selectionRect = CGRect(origin: loc, size: .zero)
        NSCursor.crosshair.set()
        needsDisplay = true
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDrawing else { return }
        let currentLoc = convert(event.locationInWindow, from: nil)
        gesturePoints.append(currentLoc)

        // Real-time bounding box update enclosing circling or highlighting
        selectionRect = SelectionGeometry.boundingRect(for: gesturePoints, padding: 6).intersection(bounds)
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        guard isDrawing else { return }
        isDrawing = false
        let loc = convert(event.locationInWindow, from: nil)
        let totalDistance = hypot(loc.x - initialMouseDownPoint.x, loc.y - initialMouseDownPoint.y)

        if totalDistance < 10.0 {
            // Tap to select: automatically construct a focused contextual bounding box
            isTapSelection = true
            selectionRect = SelectionGeometry.tapRect(at: loc, size: CGSize(width: 220, height: 160), in: bounds)
        } else {
            // Circling or highlighting: compute final bounding box
            isTapSelection = false
            selectionRect = SelectionGeometry.boundingRect(for: gesturePoints, padding: 8).intersection(bounds)
        }

        needsDisplay = true

        // Confirm immediately on release, matching Google Circle to Search workflow
        confirmSelection()
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
