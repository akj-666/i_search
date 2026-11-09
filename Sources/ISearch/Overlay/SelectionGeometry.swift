import Foundation
import CoreGraphics
import AppKit

/// Supported selection geometry shapes.
public enum SelectionShape: String, CaseIterable, Sendable {
    case rectangle
    case circle
}

/// Identifies which selection handle or region the pointer is hovering/dragging.
public enum SelectionHandle: Equatable, Sendable {
    case none
    case inside
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    public var cursor: NSCursor {
        switch self {
        case .none:
            return .crosshair
        case .inside:
            return .openHand
        case .top, .bottom:
            return .resizeUpDown
        case .left, .right:
            return .resizeLeftRight
        case .topLeft, .bottomRight:
            return .crosshair
        case .topRight, .bottomLeft:
            return .crosshair
        }
    }
}

/// Mathematical helpers for selection rectangle manipulation and handle hit testing.
public struct SelectionGeometry {
    public static let handleSize: CGFloat = 8.0
    public static let hitTolerance: CGFloat = 10.0

    /// Normalizes a rectangle from any two arbitrary points.
    public static func normalizeRect(from p1: CGPoint, to p2: CGPoint) -> CGRect {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let w = abs(p1.x - p2.x)
        let h = abs(p1.y - p2.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Tests which handle or region contains the given point.
    public static func hitTest(point: CGPoint, in rect: CGRect) -> SelectionHandle {
        guard !rect.isEmpty else { return .none }

        let tol = hitTolerance
        let minX = rect.minX
        let midX = rect.midX
        let maxX = rect.maxX
        let minY = rect.minY
        let midY = rect.midY
        let maxY = rect.maxY

        // Corner handles
        if distance(point, CGPoint(x: minX, y: maxY)) <= tol { return .topLeft }
        if distance(point, CGPoint(x: maxX, y: maxY)) <= tol { return .topRight }
        if distance(point, CGPoint(x: minX, y: minY)) <= tol { return .bottomLeft }
        if distance(point, CGPoint(x: maxX, y: minY)) <= tol { return .bottomRight }

        // Edge handles
        if distance(point, CGPoint(x: midX, y: maxY)) <= tol { return .top }
        if distance(point, CGPoint(x: midX, y: minY)) <= tol { return .bottom }
        if distance(point, CGPoint(x: minX, y: midY)) <= tol { return .left }
        if distance(point, CGPoint(x: maxX, y: midY)) <= tol { return .right }

        // Inside region
        if rect.contains(point) {
            return .inside
        }

        return .none
    }

    /// Resizes a rectangle based on dragging an active handle.
    public static func resize(rect: CGRect, handle: SelectionHandle, deltaX: CGFloat, deltaY: CGFloat) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch handle {
        case .topLeft:
            minX += deltaX
            maxY += deltaY
        case .top:
            maxY += deltaY
        case .topRight:
            maxX += deltaX
            maxY += deltaY
        case .right:
            maxX += deltaX
        case .bottomRight:
            maxX += deltaX
            minY += deltaY
        case .bottom:
            minY += deltaY
        case .bottomLeft:
            minX += deltaX
            minY += deltaY
        case .left:
            minX += deltaX
        case .inside:
            return rect.offsetBy(dx: deltaX, dy: deltaY)
        case .none:
            return rect
        }

        let newX = min(minX, maxX)
        let newY = min(minY, maxY)
        let newW = max(4, abs(maxX - minX))
        let newH = max(4, abs(maxY - minY))

        return CGRect(x: newX, y: newY, width: newW, height: newH)
    }

    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
}
