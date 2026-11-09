import Foundation

/// Available AI Providers.
public enum AIProviderType: String, CaseIterable, Identifiable, Codable {
    case mock = "mock"
    case gemini = "gemini"
    case openai = "openai"
    case claude = "claude"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mock: return "Demo Mode (Offline / OCR)"
        case .gemini: return "Google Gemini"
        case .openai: return "OpenAI (GPT-4o)"
        case .claude: return "Anthropic Claude"
        }
    }

    public var defaultModel: String {
        switch self {
        case .mock: return "On-Device Neural OCR"
        case .gemini: return "gemini-3.5-flash-lite"
        case .openai: return "gpt-4o-mini"
        case .claude: return "claude-3-5-haiku-20241022"
        }
    }

    public var keychainAccount: String {
        switch self {
        case .mock: return ""
        case .gemini: return "gemini_api_key"
        case .openai: return "openai_api_key"
        case .claude: return "claude_api_key"
        }
    }

    public var envVarName: String {
        switch self {
        case .mock: return ""
        case .gemini: return "GEMINI_API_KEY"
        case .openai: return "OPENAI_API_KEY"
        case .claude: return "ANTHROPIC_API_KEY"
        }
    }
}

/// Quick action options for selection review.
public enum QuickAction: String, CaseIterable, Identifiable {
    case explain = "Explain this"
    case readText = "Read the text"
    case identify = "Identify this"
    case custom = "Custom"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .explain: return "sparkles"
        case .readText: return "doc.text.viewfinder"
        case .identify: return "tag"
        case .custom: return "text.bubble"
        }
    }

    public var defaultPrompt: String {
        switch self {
        case .explain:
            return "Explain what is shown in this selected image in clear, concise language. Highlight the key elements and context."
        case .readText:
            return "Transcribe all visible text from this image accurately, then provide a brief explanation of what it represents."
        case .identify:
            return "Identify the primary subjects, components, diagrams, or UI elements in this image and explain their purpose."
        case .custom:
            return ""
        }
    }
}

/// Central configuration manager for AI services.
@MainActor
public final class AIConfiguration: ObservableObject {
    public static let shared = AIConfiguration()

    private let providerKey = "ISearch_SelectedProvider"
    private let modelKeyPrefix = "ISearch_Model_"
    private let customEndpointKey = "ISearch_CustomEndpoint"

    @Published public var selectedProvider: AIProviderType {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: providerKey)
        }
    }

    @Published public var customEndpoint: String {
        didSet {
            UserDefaults.standard.set(customEndpoint, forKey: customEndpointKey)
        }
    }

    private init() {
        let savedProvider = UserDefaults.standard.string(forKey: providerKey)
            .flatMap(AIProviderType.init(rawValue:)) ?? .mock
        self.selectedProvider = savedProvider
        self.customEndpoint = UserDefaults.standard.string(forKey: customEndpointKey) ?? ""
    }

    /// Returns the configured model for the given provider.
    public func getModel(for provider: AIProviderType) -> String {
        let key = modelKeyPrefix + provider.rawValue
        return UserDefaults.standard.string(forKey: key) ?? provider.defaultModel
    }

    /// Sets the model for the given provider.
    public func setModel(_ model: String, for provider: AIProviderType) {
        let key = modelKeyPrefix + provider.rawValue
        UserDefaults.standard.set(model, forKey: key)
        objectWillChange.send()
    }

    /// Retrieves the API key for the current or specified provider.
    public func getAPIKey(for provider: AIProviderType? = nil) -> String? {
        let target = provider ?? selectedProvider
        guard target != .mock else { return "mock_key" }
        return KeychainHelper.shared.getAPIKey(account: target.keychainAccount, envVarName: target.envVarName)
    }

    /// Checks if credentials are available for the specified provider.
    public func hasCredentials(for provider: AIProviderType) -> Bool {
        if provider == .mock { return true }
        guard let key = getAPIKey(for: provider) else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Factory method creating the appropriate AIService instance.
    public func createService() -> any AIService {
        switch selectedProvider {
        case .mock:
            return MockAIService()
        case .gemini:
            let apiKey = getAPIKey(for: .gemini) ?? ""
            let model = getModel(for: .gemini)
            return GeminiAIService(apiKey: apiKey, model: model)
        case .openai:
            let apiKey = getAPIKey(for: .openai) ?? ""
            let model = getModel(for: .openai)
            let endpoint = customEndpoint.isEmpty ? "https://api.openai.com/v1/chat/completions" : customEndpoint
            return OpenAIAIService(apiKey: apiKey, model: model, endpointURL: endpoint)
        case .claude:
            let apiKey = getAPIKey(for: .claude) ?? ""
            let model = getModel(for: .claude)
            return ClaudeAIService(apiKey: apiKey, model: model)
        }
    }
}
