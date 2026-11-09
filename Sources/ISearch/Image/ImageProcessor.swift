import Foundation
import AppKit
import CoreGraphics

/// Helper for in-memory image formatting, resizing, thumbnail generation, and base64 encoding.
public final class ImageProcessor: Sendable {
    public static let shared = ImageProcessor()

    private init() {}

    /// Converts CGImage to NSImage.
    public func makeNSImage(from cgImage: CGImage) -> NSImage {
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }

    /// Generates a scaled preview thumbnail suitable for compact UI display.
    public func createThumbnail(from cgImage: CGImage, maxDimension: CGFloat = 360) -> NSImage {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let aspectRatio = width / max(1, height)
        let targetSize: CGSize
        if width > height {
            targetSize = CGSize(width: min(width, maxDimension), height: min(width, maxDimension) / aspectRatio)
        } else {
            targetSize = CGSize(width: min(height, maxDimension) * aspectRatio, height: min(height, maxDimension))
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        rep.draw(in: NSRect(origin: .zero, size: targetSize))
        thumbnail.unlockFocus()

        return thumbnail
    }

    /// Compresses CGImage into high-quality JPEG Data for sending to Vision AI APIs.
    /// Resizes if dimensions exceed `maxDimension` (e.g. 1920) to keep network latency low.
    public func encodeJPEG(from cgImage: CGImage, compressionQuality: Double = 0.85, maxDimension: CGFloat = 2048) -> Data? {
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)

        var finalCGImage = cgImage

        if originalWidth > maxDimension || originalHeight > maxDimension {
            let scale = maxDimension / max(originalWidth, originalHeight)
            let newWidth = Int(originalWidth * scale)
            let newHeight = Int(originalHeight * scale)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                context.interpolationQuality = .high
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                if let resized = context.makeImage() {
                    finalCGImage = resized
                }
            }
        }

        let rep = NSBitmapImageRep(cgImage: finalCGImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: compressionQuality)])
    }

    /// Base64 encodes JPEG data.
    public func base64EncodedJPEG(from cgImage: CGImage) -> String? {
        guard let data = encodeJPEG(from: cgImage) else { return nil }
        return data.base64EncodedString()
    }
}
