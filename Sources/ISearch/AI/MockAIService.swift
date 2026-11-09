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
        try await Task.sleep(nanoseconds: 500_000_000)
        try Task.checkCancellation()

        // Perform on-device Apple Vision text recognition
        let recognizedText = performOnDeviceOCR(on: image)

        var response = ""

        // Extract user question if present
        var userQuestion: String? = nil
        if let range = prompt.range(of: "asks: \"") {
            let sub = prompt[range.upperBound...]
            if let endRange = sub.range(of: "\"") {
                userQuestion = String(sub[..<endRange.lowerBound])
            }
        } else if let range = prompt.range(of: "Follow-up question about the selected image: \"") {
            let sub = prompt[range.upperBound...]
            if let endRange = sub.range(of: "\"") {
                userQuestion = String(sub[..<endRange.lowerBound])
            }
        } else if !prompt.lowercased().contains("identify and provide") && !prompt.lowercased().contains("explain what is shown") && !prompt.isEmpty {
            userQuestion = prompt
        }

        if prompt.lowercased().contains("read the text") || prompt.lowercased().contains("transcribe") {
            response += "### 📝 Extracted Text (Transcribed)\n\n"
            if recognizedText.isEmpty {
                response += "*No prominent text was detected in the selected region.*\n\n"
            } else {
                response += "```text\n\(recognizedText)\n```\n\n"
                let count = recognizedText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
                response += "**Summary**: Extracted \(count) line(s) of text from your selection using Apple's Neural Vision.\n\n"
            }
        } else if let question = userQuestion {
            response += "### 🔍 Search Result\n\n"
            response += "**Query**: *\"\(question)\"*\n\n"

            if !recognizedText.isEmpty {
                response += "**Content Identified in Selection**:\n"
                let lines = recognizedText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                for line in lines.prefix(6) {
                    response += "- `\(line)`\n"
                }
                response += "\n"
            }

            response += "**Explanation**: "
            if question.lowercased().contains("cat") || question.lowercased().contains("dog") || question.lowercased().contains("pet") {
                response += "Based on identifying the selected item in context, always ensure pets do not ingest unknown plants, objects, or materials. For houseplants, common varieties like lilies and pothos are toxic to pets, while spider plants and Boston ferns are safe alternatives."
            } else if question.lowercased().contains("safe") {
                response += "Based on the content and elements in the selected screen area, this appears standard and safe for normal use in this application."
            } else if question.lowercased().contains("buy") || question.lowercased().contains("shop") || question.lowercased().contains("price") {
                response += "This item or product was identified on your screen. You can find availability, specifications, and pricing through authorized retailers or by searching the identified title."
            } else if !recognizedText.isEmpty {
                response += "The selected region features the text and elements listed above. This provides the relevant context answering your inquiry from your active screen."
            } else {
                response += "The selected visual content represents an active graphical item or element in your current application window."
            }
            response += "\n\n"
        } else {
            response += "### 🔍 Search Results & Information\n\n"
            if !recognizedText.isEmpty {
                response += "**Detected Text & Key Elements**:\n"
                let lines = recognizedText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                for line in lines.prefix(6) {
                    response += "- `\(line)`\n"
                }
                response += "\n"
                response += "**Summary**: The selected screen region contains \(lines.count) visible text line(s). This appears to be part of an active window, code file, document, or website on your Mac."
            } else {
                response += "**Overview**: Selected visual image captured on your screen.\n\n"
                response += "**Explanation**: The selected region highlights graphical or UI content without machine-readable text. You can ask follow-up questions below or type a query in the search bar."
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
