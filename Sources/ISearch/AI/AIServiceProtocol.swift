import Foundation

/// Errors that can occur during AI analysis.
public enum AIError: LocalizedError {
    case missingCredentials(provider: String)
    case invalidResponse(message: String)
    case networkError(underlying: Error)
    case rateLimited
    case timeout
    case canceled

    public var errorDescription: String? {
        switch self {
        case .missingCredentials(let provider):
            return "No API key configured for \(provider). Add your key in Settings or switch to Demo Mode."
        case .invalidResponse(let message):
            return "AI service error: \(message)"
        case .networkError(let underlying):
            return "Network connection failed: \(underlying.localizedDescription)"
        case .rateLimited:
            return "Rate limit exceeded. Please wait a moment before trying again."
        case .timeout:
            return "The request timed out. Please try again."
        case .canceled:
            return "Request was canceled."
        }
    }
}

/// Abstract vision-capable AI service protocol.
public protocol AIService: Sendable {
    var providerName: String { get }

    /// Analyzes an image with a prompt.
    /// - Parameters:
    ///   - image: Raw JPEG or PNG data.
    ///   - prompt: Question or instruction from the user.
    ///   - mimeType: MIME type, e.g. "image/jpeg".
    /// - Returns: Text response from the model.
    func analyze(image: Data, prompt: String, mimeType: String) async throws -> String
}
