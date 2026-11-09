import Foundation
import CoreGraphics
import AppKit
import Carbon

@main
struct TestRunner {
    static func main() async throws {
        print("========================================")
        print("  Running i search Component Verifications")
        print("========================================")

        // 1. Test KeyCombo
        print("==> 1. Testing KeyCombo...")
        let defaultCombo = KeyCombo.default
        assert(defaultCombo.keyCode == UInt32(kVK_ANSI_1), "Default keycode must be 1")
        assert(defaultCombo.displayString.contains("1"), "Display string must contain 1")
        assert(defaultCombo.displayString.contains("⌘"), "Display string must contain ⌘")
        assert(defaultCombo.displayString.contains("⇧"), "Display string must contain ⇧")

        let data = try JSONEncoder().encode(defaultCombo)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)
        assert(decoded == defaultCombo, "KeyCombo encoding/decoding must match")
        print("   ✓ KeyCombo tests passed.")

        // 2. Test SelectionGeometry
        print("==> 2. Testing SelectionGeometry...")
        let p1 = CGPoint(x: 200, y: 150)
        let p2 = CGPoint(x: 50, y: 30)
        let normRect = SelectionGeometry.normalizeRect(from: p1, to: p2)
        assert(normRect.origin.x == 50 && normRect.origin.y == 30, "Origin must be min coords")
        assert(normRect.width == 150 && normRect.height == 120, "Width/height must be positive diff")

        // Hit tests
        let insideHit = SelectionGeometry.hitTest(point: CGPoint(x: 100, y: 100), in: normRect)
        assert(insideHit == .inside, "Point inside must return .inside")

        let outsideHit = SelectionGeometry.hitTest(point: CGPoint(x: 10, y: 10), in: normRect)
        assert(outsideHit == .none, "Point outside must return .none")

        let topLeftHit = SelectionGeometry.hitTest(point: CGPoint(x: 50, y: 150), in: normRect)
        assert(topLeftHit == .topLeft, "Top-left handle must be detected")

        // Resize
        let resized = SelectionGeometry.resize(rect: normRect, handle: .right, deltaX: 20, deltaY: 0)
        assert(resized.width == 170, "Width must expand by 20")

        // Circling / freeform bounding box
        let circlePoints = [CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 150), CGPoint(x: 150, y: 300)]
        let boundRect = SelectionGeometry.boundingRect(for: circlePoints, padding: 10)
        assert(boundRect.minX == 90 && boundRect.maxX == 210, "Bounding box minX/maxX must include padding")
        assert(boundRect.minY == 90 && boundRect.maxY == 310, "Bounding box minY/maxY must include padding")

        // Tap rect
        let tap = SelectionGeometry.tapRect(at: CGPoint(x: 500, y: 400), size: CGSize(width: 220, height: 160), in: CGRect(x: 0, y: 0, width: 1440, height: 900))
        assert(tap.width == 220 && tap.height == 160, "Tap rect must match target size")
        assert(tap.midX == 500 && tap.midY == 400, "Tap rect must be centered around tap point")
        print("   ✓ SelectionGeometry tests passed.")

        // 3. Test ImageProcessor
        print("==> 3. Testing ImageProcessor...")
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: 100,
            height: 60,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            fatalError("Failed to create test CGContext")
        }
        ctx.setFillColor(NSColor.red.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 60))
        guard let testImage = ctx.makeImage() else {
            fatalError("Failed to create test CGImage")
        }

        let nsImage = ImageProcessor.shared.makeNSImage(from: testImage)
        assert(nsImage.size.width == 100 && nsImage.size.height == 60, "NSImage size must match")

        let thumb = ImageProcessor.shared.createThumbnail(from: testImage, maxDimension: 50)
        assert(thumb.size.width <= 50 && thumb.size.height <= 50, "Thumbnail must fit within maxDimension")

        guard let jpegData = ImageProcessor.shared.encodeJPEG(from: testImage) else {
            fatalError("Failed to encode JPEG")
        }
        assert(jpegData.count > 0, "JPEG data must not be empty")
        // JPEG magic bytes: 0xFF 0xD8
        assert(jpegData[0] == 0xFF && jpegData[1] == 0xD8, "JPEG magic header must match")

        let base64 = ImageProcessor.shared.base64EncodedJPEG(from: testImage)
        assert(base64 != nil && !(base64?.isEmpty ?? true), "Base64 string must be generated")
        print("   ✓ ImageProcessor tests passed.")

        // 4. Test MockAIService
        print("==> 4. Testing MockAIService...")
        let mockService = MockAIService()
        let response = try await mockService.analyze(image: jpegData, prompt: "Explain this selection", mimeType: "image/jpeg")
        assert(response.contains("Overview") || response.contains("Explanation"), "Response must contain explanation header")
        assert(response.contains("Demo Mode"), "Response must include Demo Mode footer")

        let readTextResponse = try await mockService.analyze(image: jpegData, prompt: "Read the text", mimeType: "image/jpeg")
        assert(readTextResponse.contains("Extracted Text"), "Read text response must contain Extracted Text header")

        let questionPrompt = "The user selected an area on their screen and asks: \"Is it safe for cats?\""
        let questionResponse = try await mockService.analyze(image: jpegData, prompt: questionPrompt, mimeType: "image/jpeg")
        assert(questionResponse.contains("Is it safe for cats?"), "Response must reference question")
        assert(questionResponse.contains("cat") || questionResponse.contains("pet"), "Response must address cat safety")
        print("   ✓ MockAIService tests passed.")

        // 5. Test KeychainHelper
        print("==> 5. Testing KeychainHelper...")
        let testAccount = "isearch_test_key"
        let testSecret = "test_secret_value_12345"
        _ = KeychainHelper.shared.saveSecret(testSecret, for: testAccount)
        let readSecret = KeychainHelper.shared.readSecret(for: testAccount)
        assert(readSecret == testSecret, "Saved secret must match retrieved secret")
        _ = KeychainHelper.shared.deleteSecret(for: testAccount)
        let deletedSecret = KeychainHelper.shared.readSecret(for: testAccount)
        assert(deletedSecret == nil, "Secret must be nil after deletion")
        print("   ✓ KeychainHelper tests passed.")

        print("========================================")
        print("  All Component Verifications PASSED! ✅")
        print("========================================")
    }
}
