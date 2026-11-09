import Foundation

/// OpenAI / OpenAI-compatible Vision API implementation.
public final class OpenAIAIService: AIService, Sendable {
    public let providerName = "OpenAI"
    private let apiKey: String
    private let model: String
    private let endpointURL: String

    public init(apiKey: String, model: String, endpointURL: String = "https://api.openai.com/v1/chat/completions") {
        self.apiKey = apiKey
        self.model = model.isEmpty ? "gpt-4o-mini" : model
        self.endpointURL = endpointURL
    }

    public func analyze(image: Data, prompt: String, mimeType: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.missingCredentials(provider: "OpenAI")
        }

        try Task.checkCancellation()

        guard let url = URL(string: endpointURL) else {
            throw AIError.invalidResponse(message: "Invalid OpenAI endpoint URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45

        let base64Image = image.base64EncodedString()
        let dataURI = "data:\(mimeType);base64,\(base64Image)"

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": dataURI
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 2048
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
                throw AIError.invalidResponse(message: "OpenAI API error (\(httpResponse.statusCode)): \(message)")
            }
            let rawString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.invalidResponse(message: "OpenAI API HTTP \(httpResponse.statusCode): \(rawString)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse(message: "Could not parse message content from OpenAI response.")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
