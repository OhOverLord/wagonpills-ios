import Foundation
import Security

protocol TokenStore: Sendable {
    func loadTokens() throws -> TokenPair?
    func save(_ pair: TokenPair) throws
    func clear() throws
}

struct TokenPair: Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let email: String
}

struct KeychainStore: TokenStore {
    private static let service = "com.wagonpills.ios.auth"
    private static let accessAccount = "access"
    private static let refreshAccount = "refresh"
    private static let emailDefaultsKey = "com.wagonpills.ios.auth.email"

    // Keychain items survive app uninstall when the device has a prior iCloud or
    // iTunes backup. On a clean device with no backup, items are wiped on uninstall.
    // In practice the server will reject a stale token with 401, triggering re-login.

    nonisolated func loadTokens() throws -> TokenPair? {
        guard
            let access = try Self.keychainLoad(account: Self.accessAccount),
            let refresh = try Self.keychainLoad(account: Self.refreshAccount)
        else {
            return nil
        }
        let email = UserDefaults.standard.string(forKey: Self.emailDefaultsKey) ?? ""
        return TokenPair(accessToken: access, refreshToken: refresh, email: email)
    }

    nonisolated func save(_ pair: TokenPair) throws {
        try Self.keychainUpsert(account: Self.accessAccount, value: pair.accessToken)
        try Self.keychainUpsert(account: Self.refreshAccount, value: pair.refreshToken)
        UserDefaults.standard.set(pair.email, forKey: Self.emailDefaultsKey)
    }

    nonisolated func clear() throws {
        try Self.keychainDelete(account: Self.accessAccount)
        try Self.keychainDelete(account: Self.refreshAccount)
        UserDefaults.standard.removeObject(forKey: Self.emailDefaultsKey)
    }
}

// MARK: - Private Keychain helpers

private extension KeychainStore {
    nonisolated static func keychainLoad(account: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw APIError.unexpected("Keychain returned non-UTF8 data (account: \(account))")
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw APIError.unexpected("Keychain load failed — OSStatus \(status) (account: \(account))")
        }
    }

    nonisolated static func keychainUpsert(account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw APIError.unexpected("Could not encode token value as UTF-8")
        }
        let addAttributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable: false
        ]
        let addStatus = SecItemAdd(addAttributes as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw APIError.unexpected("Keychain update failed — OSStatus \(updateStatus) (account: \(account))")
            }
        } else if addStatus != errSecSuccess {
            throw APIError.unexpected("Keychain add failed — OSStatus \(addStatus) (account: \(account))")
        }
    }

    nonisolated static func keychainDelete(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIError.unexpected("Keychain delete failed — OSStatus \(status) (account: \(account))")
        }
    }
}
