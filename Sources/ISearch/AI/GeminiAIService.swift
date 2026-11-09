import Foundation

/// Google Gemini Vision API implementation with automatic retries and intelligent fallback.
public final class GeminiAIService: AIService, Sendable {
    public let providerName = "Google Gemini"
    private let apiKey: String
    private let model: String

    public init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model.isEmpty ? "gemini-3.5-flash-lite" : model
    }

    public func analyze(image: Data, prompt: String, mimeType: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.missingCredentials(provider: "Google Gemini")
        }

        try Task.checkCancellation()

        // Automatically map legacy/deprecated models (2.5, 2.0, 1.5) to active equivalents
        let primaryModel: String
        if model.contains("2.5") || model.contains("2.0") || model.contains("1.5") {
            primaryModel = "gemini-3.5-flash-lite"
        } else {
            primaryModel = model
        }

        do {
            return try await executeWithRetries(model: primaryModel, image: image, prompt: prompt, mimeType: mimeType)
        } catch let error as AIError {
            // If primary model failed due to high demand (503) or rate limits (429) and wasn't already 3.5-flash-lite, fallback to 3.5-flash-lite
            if primaryModel != "gemini-3.5-flash-lite" {
                switch error {
                case .invalidResponse(let msg) where msg.contains("503") || msg.contains("high demand") || msg.contains("overloaded"):
                    NSLog("[GeminiAIService] '%@' overloaded (503), falling back to 'gemini-3.5-flash-lite'", primaryModel)
                    return try await executeWithRetries(model: "gemini-3.5-flash-lite", image: image, prompt: prompt, mimeType: mimeType)
                case .rateLimited:
                    NSLog("[GeminiAIService] '%@' rate limited, falling back to 'gemini-3.5-flash-lite'", primaryModel)
                    return try await executeWithRetries(model: "gemini-3.5-flash-lite", image: image, prompt: prompt, mimeType: mimeType)
                default:
                    throw error
                }
            }
            throw error
        }
    }

    private func executeWithRetries(model: String, image: Data, prompt: String, mimeType: String, maxAttempts: Int = 3) async throws -> String {
        var lastError: Error?
        var backoffSeconds: UInt64 = 1

        for attempt in 1...maxAttempts {
            try Task.checkCancellation()
            do {
                return try await performRequest(model: model, image: image, prompt: prompt, mimeType: mimeType)
            } catch let error as AIError {
                lastError = error
                switch error {
                case .invalidResponse(let msg) where msg.contains("503") || msg.contains("high demand") || msg.contains("overloaded"):
                    if attempt < maxAttempts {
                        try? await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)
                        backoffSeconds *= 2
                        continue
                    }
                case .rateLimited:
                    if attempt < maxAttempts {
                        try? await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)
                        backoffSeconds *= 2
                        continue
                    }
                default:
                    throw error
                }
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)
                    backoffSeconds *= 2
                    continue
                }
            }
        }

        if let error = lastError as? AIError {
            throw error
        } else if let error = lastError {
            throw AIError.networkError(underlying: error)
        } else {
            throw AIError.invalidResponse(message: "Failed to connect to Gemini after multiple attempts.")
        }
    }

    private func performRequest(model: String, image: Data, prompt: String, mimeType: String) async throws -> String {
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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse(message: "Received invalid server response.")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                if httpResponse.statusCode == 503 {
                    throw AIError.invalidResponse(message: "Model '\(model)' is experiencing high demand (503). Change Model Name to 'gemini-3.5-flash-lite'.")
                }
                throw AIError.invalidResponse(message: "Gemini error (\(httpResponse.statusCode)): \(message)")
            }
            if httpResponse.statusCode == 429 {
                throw AIError.rateLimited
            }
            if httpResponse.statusCode == 503 {
                throw AIError.invalidResponse(message: "Model '\(model)' is experiencing high demand (503). Change Model Name to 'gemini-3.5-flash-lite'.")
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
