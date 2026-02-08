import Foundation
import Security
import os

private let logger = Logger(subsystem: "com.edgeoftrust.remmy", category: "Keychain")

/// Minimal Keychain wrapper for storing secrets securely.
/// Uses kSecClassGenericPassword with kSecAttrAccessibleAfterFirstUnlock.
enum KeychainHelper {

    private static let service = "com.edgeoftrust.remmy"

    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        // Delete any existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Keychain save failed for \(key): \(status)")
        }
        return status == errSecSuccess
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logger.error("Keychain load failed for \(key): \(status)")
            }
            return nil
        }

        return result as? Data
    }

    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - String convenience

    @discardableResult
    static func saveString(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }

    static func loadString(key: String) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Migration

    /// Migrate a string value from UserDefaults to Keychain.
    /// If value exists in UserDefaults but not Keychain, copies it over and removes from UserDefaults.
    static func migrateString(userDefaultsKey: String, keychainKey: String) {
        // Already in Keychain? Nothing to do.
        if loadString(key: keychainKey) != nil { return }

        // Exists in UserDefaults? Migrate it.
        if let value = UserDefaults.standard.string(forKey: userDefaultsKey) {
            if saveString(key: keychainKey, value: value) {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                logger.info("Migrated \(keychainKey) from UserDefaults to Keychain")
            }
        }
    }
}
