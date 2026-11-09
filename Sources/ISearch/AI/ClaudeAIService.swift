import Foundation

/// Anthropic Claude Vision API implementation.
public final class ClaudeAIService: AIService, Sendable {
    public let providerName = "Anthropic Claude"
    private let apiKey: String
    private let model: String

    public init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model.isEmpty ? "claude-3-5-haiku-20241022" : model
    }

    public func analyze(image: Data, prompt: String, mimeType: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.missingCredentials(provider: "Anthropic Claude")
        }

        try Task.checkCancellation()

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIError.invalidResponse(message: "Invalid Anthropic API URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 45

        let base64Image = image.base64EncodedString()

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": mimeType,
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
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

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw AIError.invalidResponse(message: "Claude error (\(httpResponse.statusCode)): \(message)")
            }
            if httpResponse.statusCode == 429 {
                throw AIError.rateLimited
            }
            let rawString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.invalidResponse(message: "Claude API HTTP \(httpResponse.statusCode): \(rawString)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIError.invalidResponse(message: "Could not parse text from Claude response.")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
