import Foundation
import Vision
import AppKit

/// High-quality mock/offline AI service using on-device Apple Vision text recognition.
public final class MockAIService: AIService, Sendable {
    public let providerName = "Demo Mode (Offline Vision)"

    public init() {}

    public func analyze(image: Data, prompt: String, mimeType: String) async throws -> String {
        // Check for cancellation
        try Task.checkCancellation()

        // Simulate brief realistic processing delay
        try await Task.sleep(nanoseconds: 600_000_000)
        try Task.checkCancellation()

        // Perform on-device Apple Vision text recognition
        let recognizedText = performOnDeviceOCR(on: image)

        var response = ""

        if prompt.lowercased().contains("read the text") || prompt.lowercased().contains("transcribe") {
            response += "### 📝 Extracted Text\n\n"
            if recognizedText.isEmpty {
                response += "*No prominent text was detected in the selected region.*\n\n"
            } else {
                response += "```text\n\(recognizedText)\n```\n\n"
                response += "**Summary**: The selection contains \(recognizedText.components(separatedBy: .newlines).count) lines of text.\n\n"
            }
        } else if prompt.lowercased().contains("identify") {
            response += "### 🔍 Identification\n\n"
            if !recognizedText.isEmpty {
                response += "**Detected Content**: Visible elements and text identified:\n"
                response += "> \(recognizedText.components(separatedBy: .newlines).prefix(3).joined(separator: " • "))\n\n"
            }
            response += "**Classification**: Screen element / UI region captured from macOS.\n"
            response += "**Context**: Rectangular selection captured for contextual analysis.\n\n"
        } else {
            response += "### ✨ Overview\n\n"
            response += "This screen selection captures visual content from your active workspace.\n\n"
            if !recognizedText.isEmpty {
                response += "**Key Text / Elements Identified**:\n"
                for line in recognizedText.components(separatedBy: .newlines).prefix(4) where !line.isEmpty {
                    response += "- `\(line)`\n"
                }
                response += "\n"
            }
            response += "**Explanation**: "
            if !prompt.isEmpty && !prompt.contains("Explain what is shown") {
                response += "Regarding your question: *\"\(prompt)\"*\n\nBased on the visual features in the selected region, this content appears to be an active interface or document element."
            } else {
                response += "The selected region highlights active content on your screen. You can interact with or extract this information directly."
            }
            response += "\n\n"
        }

        response += "---\n"
        response += "> 💡 *Demo Mode: Running offline on-device Apple Vision. To unlock full multimodal AI reasoning, configure your Google Gemini, OpenAI, or Claude API key in Settings.*"

        return response
    }

    private func performOnDeviceOCR(on imageData: Data) -> String {
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }

        var results: [String] = []
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    results.append(candidate.string)
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            NSLog("[MockAIService] OCR failed: %@", error.localizedDescription)
        }

        return results.joined(separator: "\n")
    }
}
