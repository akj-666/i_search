import Foundation
import Security

/// Thread-safe helper for storing and retrieving API keys in macOS Keychain with environment variable fallback.
public final class KeychainHelper: Sendable {
    public static let shared = KeychainHelper()

    private let serviceName = "com.isearch.app"

    private init() {}

    /// Saves a secret string to the macOS Keychain.
    @discardableResult
    public func saveSecret(_ secret: String, for account: String) -> Bool {
        guard let data = secret.data(using: .utf8) else { return false }

        // Delete existing item first
        deleteSecret(for: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Reads a secret string from the macOS Keychain.
    public func readSecret(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    /// Deletes a secret from the Keychain.
    @discardableResult
    public func deleteSecret(for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Retrieves an API key, checking Keychain first, then environment variable fallback.
    public func getAPIKey(account: String, envVarName: String) -> String? {
        if let keychainValue = readSecret(for: account), !keychainValue.isEmpty {
            return keychainValue
        }
        if let envValue = ProcessInfo.processInfo.environment[envVarName], !envValue.isEmpty {
            return envValue
        }
        return nil
    }
}
