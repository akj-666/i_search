import SwiftUI

@MainActor
public final class AISettingsViewModel: ObservableObject {
    @Published public var currentApiKeyInput: String = ""
    @Published public var selectedModel: String = ""
    @Published public var testStatusMessage: String?
    @Published public var isTesting: Bool = false
    @Published public var hasKeyInKeychain: Bool = false

    public init() {}
}

/// Settings section for configuring AI providers, models, and Keychain API keys.
public struct AISettingsView: View {
    @ObservedObject private var aiConfig = AIConfiguration.shared
    @StateObject private var vm = AISettingsViewModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Provider Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("AI Provider")
                    .font(.system(size: 13, weight: .semibold))

                Picker("", selection: $aiConfig.selectedProvider) {
                    ForEach(AIProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: aiConfig.selectedProvider) {
                    refreshState()
                }
            }

            Divider()

            if aiConfig.selectedProvider == .mock {
                // Demo Mode Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        Text("Demo Mode Active")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    Text("Runs 100% locally and offline using Apple's Neural Vision framework to extract text and analyze screen selections without requiring an API key or internet connection.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
            } else {
                // Model Configuration
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Model Name")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("Default: \(aiConfig.selectedProvider.defaultModel)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    TextField("e.g. \(aiConfig.selectedProvider.defaultModel)", text: $vm.selectedModel)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onChange(of: vm.selectedModel) { _, newValue in
                            aiConfig.setModel(newValue, for: aiConfig.selectedProvider)
                            vm.testStatusMessage = nil
                        }

                    // Recommended Model Pills
                    HStack(spacing: 6) {
                        ForEach(recommendedModels(for: aiConfig.selectedProvider), id: \.self) { modelName in
                            Button(action: {
                                vm.selectedModel = modelName
                                aiConfig.setModel(modelName, for: aiConfig.selectedProvider)
                            }) {
                                Text(modelName)
                                    .font(.system(size: 10, weight: vm.selectedModel == modelName ? .bold : .regular))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(vm.selectedModel == modelName ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(vm.selectedModel == modelName ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 0.5)
                                    )
                                    .foregroundColor(vm.selectedModel == modelName ? .accentColor : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }

                // API Key Configuration
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("API Key")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        if vm.hasKeyInKeychain {
                            HStack(spacing: 4) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 10))
                                Text("Saved in Keychain")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.green)
                        }
                    }

                    HStack(spacing: 8) {
                        SecureField(vm.hasKeyInKeychain ? "••••••••••••••••••••••••" : "Paste API key here...", text: $vm.currentApiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))

                        Button("Save") {
                            saveApiKey()
                        }
                        .disabled(vm.currentApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if vm.hasKeyInKeychain {
                            Button("Clear") {
                                clearApiKey()
                            }
                        }
                    }

                    Text("API keys are saved in your macOS Keychain. Environment variable \(aiConfig.selectedProvider.envVarName) is also checked.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // Optional Custom Endpoint (OpenAI)
                if aiConfig.selectedProvider == .openai {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Custom API Base URL (Optional)")
                            .font(.system(size: 12, weight: .medium))

                        TextField("https://api.openai.com/v1/chat/completions", text: $aiConfig.customEndpoint)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))

                        Text("Leave blank for default OpenAI endpoint, or specify for Ollama / Groq / OpenRouter.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                // Test Connection
                HStack(spacing: 12) {
                    Button(action: testConnection) {
                        HStack(spacing: 6) {
                            if vm.isTesting {
                                ProgressView()
                                    .scaleEffect(0.6)
                            }
                            Text(vm.isTesting ? "Testing..." : "Test Connection")
                        }
                    }
                    .disabled(vm.isTesting || !hasCurrentProviderCredentials)

                    if let message = vm.testStatusMessage {
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundColor(message.contains("Successful") ? .green : .red)
                    }
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            refreshState()
        }
    }

    private func refreshState() {
        vm.selectedModel = aiConfig.getModel(for: aiConfig.selectedProvider)
        let key = KeychainHelper.shared.readSecret(for: aiConfig.selectedProvider.keychainAccount)
        vm.hasKeyInKeychain = (key != nil && !(key?.isEmpty ?? true))
        vm.currentApiKeyInput = ""
        vm.testStatusMessage = nil
    }

    private func saveApiKey() {
        let trimmed = vm.currentApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let success = KeychainHelper.shared.saveSecret(trimmed, for: aiConfig.selectedProvider.keychainAccount)
        if success {
            vm.hasKeyInKeychain = true
            vm.currentApiKeyInput = ""
            vm.testStatusMessage = "Key saved to Keychain."
        }
    }

    private func clearApiKey() {
        KeychainHelper.shared.deleteSecret(for: aiConfig.selectedProvider.keychainAccount)
        vm.hasKeyInKeychain = false
        vm.currentApiKeyInput = ""
        vm.testStatusMessage = "Key removed from Keychain."
    }

    private func testConnection() {
        vm.isTesting = true
        vm.testStatusMessage = nil

        Task {
            do {
                // Generate a 1x1 test image byte
                let service = aiConfig.createService()
                let testPNG = createTestImageData()
                _ = try await service.analyze(image: testPNG, prompt: "Ping. Respond with OK.", mimeType: "image/png")
                await MainActor.run {
                    self.vm.isTesting = false
                    self.vm.testStatusMessage = "✓ Connection Successful"
                }
            } catch {
                await MainActor.run {
                    self.vm.isTesting = false
                    self.vm.testStatusMessage = "✗ Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func createTestImageData() -> Data {
        let size = CGSize(width: 8, height: 8)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return png
    }

    private var hasCurrentProviderCredentials: Bool {
        if aiConfig.selectedProvider == .mock { return true }
        if vm.hasKeyInKeychain { return true }
        if let envVal = ProcessInfo.processInfo.environment[aiConfig.selectedProvider.envVarName], !envVal.isEmpty {
            return true
        }
        return false
    }

    private func recommendedModels(for provider: AIProviderType) -> [String] {
        switch provider {
        case .gemini:
            return ["gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-3.1-flash-lite", "gemini-4-argon"]
        case .openai:
            return ["gpt-4o-mini", "gpt-4o"]
        case .claude:
            return ["claude-3-5-haiku-20241022", "claude-3-5-sonnet-20241022"]
        case .mock:
            return []
        }
    }
}
