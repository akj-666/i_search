import Foundation
import Security

/// Thread-safe helper for storing and retrieving API keys in macOS Keychain with environment variable fallback and in-memory caching.
public final class KeychainHelper: @unchecked Sendable {
    public static let shared = KeychainHelper()

    private let serviceName = "com.isearch.app"
    private let lock = NSLock()
    private var memoryCache: [String: String] = [:]

    private init() {}

    /// Saves a secret string to the macOS Keychain.
    @discardableResult
    public func saveSecret(_ secret: String, for account: String) -> Bool {
        guard let data = secret.data(using: .utf8) else { return false }

        lock.lock()
        memoryCache[account] = secret
        lock.unlock()

        // Delete existing item first
        deleteSecret(for: account, clearCache: false)

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

    /// Reads a secret string from in-memory cache or macOS Keychain.
    public func readSecret(for account: String) -> String? {
        lock.lock()
        if let cached = memoryCache[account] {
            lock.unlock()
            return cached
        }
        lock.unlock()

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
            let secret = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let secret = secret {
                lock.lock()
                memoryCache[account] = secret
                lock.unlock()
            }
            return secret
        }

        return nil
    }

    /// Deletes a secret from the Keychain.
    @discardableResult
    public func deleteSecret(for account: String, clearCache: Bool = true) -> Bool {
        if clearCache {
            lock.lock()
            memoryCache.removeValue(forKey: account)
            lock.unlock()
        }

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
