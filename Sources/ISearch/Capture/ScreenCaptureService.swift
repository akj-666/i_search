import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit

/// High-performance screen capture service supporting ScreenCaptureKit and CoreGraphics fallback.
public final class ScreenCaptureService: Sendable {
    public static let shared = ScreenCaptureService()

    public enum CaptureError: LocalizedError {
        case permissionDenied
        case emptySelection
        case captureFailed
        case invalidImageData

        public var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Screen Recording permission is required. Please grant permission in System Settings."
            case .emptySelection:
                return "The selected area is too small to capture."
            case .captureFailed:
                return "Failed to capture the selected screen region."
            case .invalidImageData:
                return "The captured image data could not be processed."
            }
        }
    }

    private init() {}

    /// Captures the specified AppKit global rect.
    /// - Parameters:
    ///   - appKitRect: Rect in AppKit screen coordinates (bottom-left origin).
    ///   - targetScreen: The NSScreen where the selection occurred.
    /// - Returns: High-resolution CGImage of the selected region.
    public func captureRegion(appKitRect: CGRect, on targetScreen: NSScreen) async throws -> CGImage {
        guard appKitRect.width >= 4 && appKitRect.height >= 4 else {
            throw CaptureError.emptySelection
        }

        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }

        // Convert AppKit rect (bottom-left origin) to CoreGraphics rect (top-left origin of primary screen)
        let primaryScreen = NSScreen.screens.first ?? targetScreen
        let primaryHeight = primaryScreen.frame.height

        let cgX = appKitRect.origin.x
        let cgY = primaryHeight - (appKitRect.origin.y + appKitRect.height)
        let cgRect = CGRect(x: cgX, y: cgY, width: appKitRect.width, height: appKitRect.height)

        // Try modern ScreenCaptureKit first if available
        if #available(macOS 14.0, *) {
            do {
                return try await captureWithScreenCaptureKit(cgRect: cgRect, targetScreen: targetScreen)
            } catch {
                NSLog("[ScreenCaptureService] ScreenCaptureKit failed (%@), falling back to CoreGraphics", error.localizedDescription)
            }
        }

        // Fallback to CoreGraphics CGWindowListCreateImage
        return try captureWithCoreGraphics(cgRect: cgRect)
    }

    // MARK: - CoreGraphics Fallback

    @available(macOS, deprecated: 14.0, message: "Fallback for legacy capture")
    private func captureWithCoreGraphics(cgRect: CGRect) throws -> CGImage {
        guard let image = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .nominalResolution]
        ) else {
            throw CaptureError.captureFailed
        }
        return image
    }

    // MARK: - ScreenCaptureKit

    @available(macOS 14.0, *)
    private func captureWithScreenCaptureKit(cgRect: CGRect, targetScreen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Find the SCDisplay corresponding to the targetScreen
        guard let displayID = targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let scDisplay = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            return try captureWithCoreGraphics(cgRect: cgRect)
        }

        // Content filter for display
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])

        let config = SCStreamConfiguration()
        let scale = targetScreen.backingScaleFactor

        // Adjust coordinates relative to display origin
        let displayBounds = CGDisplayBounds(scDisplay.displayID)
        let localRect = CGRect(
            x: max(0, cgRect.origin.x - displayBounds.origin.x),
            y: max(0, cgRect.origin.y - displayBounds.origin.y),
            width: min(cgRect.width, displayBounds.width),
            height: min(cgRect.height, displayBounds.height)
        )

        config.sourceRect = localRect
        config.width = Int(localRect.width * scale)
        config.height = Int(localRect.height * scale)
        config.showsCursor = false

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
