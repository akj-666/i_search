import Foundation

/// Google Gemini Vision API implementation.
public final class GeminiAIService: AIService, Sendable {
    public let providerName = "Google Gemini"
    private let apiKey: String
    private let model: String

    public init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model.isEmpty ? "gemini-2.0-flash" : model
    }

    public func analyze(image: Data, prompt: String, mimeType: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.missingCredentials(provider: "Google Gemini")
        }

        try Task.checkCancellation()

        let endpointString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpointString) else {
            throw AIError.invalidResponse(message: "Invalid Gemini API URL configuration.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

        let base64Image = image.base64EncodedString()

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": mimeType,
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.4,
                "maxOutputTokens": 2048
            ]
        ]

        let requestData = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = requestData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw AIError.canceled
        } catch {
            throw AIError.networkError(underlying: error)
        }

        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse(message: "Received invalid server response.")
        }

        if httpResponse.statusCode == 429 {
            throw AIError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw AIError.invalidResponse(message: "Gemini API error (\(httpResponse.statusCode)): \(message)")
            }
            let rawString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.invalidResponse(message: "Gemini API HTTP \(httpResponse.statusCode): \(rawString)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIError.invalidResponse(message: "Could not parse candidate text from Gemini response.")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
