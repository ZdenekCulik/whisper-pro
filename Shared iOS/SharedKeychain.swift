import Foundation
import Security

/// Keychain storage shared between the iOS app and the keyboard extension.
/// Deliberately separate from the macOS KeychainService so the Mac app is untouched.
enum SharedKeychain {
    static let sonioxKey = "sonioxAPIKey"

    private static let service = "com.prakashjoshipax.WhisperPro"
    private static let accessGroup = "A6D3VFTJYT.com.prakashjoshipax.WhisperPro.shared"

    private static func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup
        ]
    }

    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        let query = baseQuery(forKey: key)
        SecItemDelete(query as CFDictionary)
        guard let data = value.data(using: .utf8) else { return false }
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    static func get(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else { return nil }
        return value
    }
}
