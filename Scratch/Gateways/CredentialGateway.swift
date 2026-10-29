import Foundation
import Security

/// Where the signed-in server is kept between launches (SRV-5).
protocol CredentialGateway {
    func load() -> SavedServer?
    func save(_ server: SavedServer) throws(StorageError)

    func delete() throws(StorageError)
}

/// The salt and token go in the Keychain; the URL and username in UserDefaults. The password is
/// never stored (SRV-4).
final class KeychainCredentialGateway: CredentialGateway {
    private enum Key {
        static let baseURL = "server.baseURL"
        static let username = "server.username"
    }

    private let defaults: UserDefaults
    private let service: String
    private let keychainAccount = "subsonic-token"

    init(environment: AppEnvironment) {
        defaults = environment.defaults
        service = environment.keychainService
    }

    func load() -> SavedServer? {
        guard let urlString = defaults.string(forKey: Key.baseURL),
              let baseURL = URL(string: urlString),
              let username = defaults.string(forKey: Key.username),
              let secret = readSecret()
        else { return nil }
        return SavedServer(
            account: ServerAccount(baseURL: baseURL, username: username),
            credentials: SubsonicCredentials(username: username, salt: secret.salt, token: secret.token)
        )
    }

    func save(_ server: SavedServer) throws(StorageError) {
        try writeSecret(Secret(salt: server.credentials.salt, token: server.credentials.token))
        defaults.set(server.account.baseURL.absoluteString, forKey: Key.baseURL)
        defaults.set(server.account.username, forKey: Key.username)
    }

    /// Forgets the URL and username even if the Keychain refuses to delete the token, so a sign
    /// out always holds: without them, `load()` finds nothing, and a leftover salt and token are
    /// no use on their own.
    func delete() throws(StorageError) {
        defaults.removeObject(forKey: Key.baseURL)
        defaults.removeObject(forKey: Key.username)
        let status = SecItemDelete(query() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw .keychain(status: status) }
    }

    private struct Secret: Codable {
        var salt: String
        var token: String
    }

    private func query() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keychainAccount,
        ]
    }

    private func readSecret() -> Secret? {
        var query = query()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }

        return try? JSONDecoder().decode(Secret.self, from: data)
    }

    private func writeSecret(_ secret: Secret) throws(StorageError) {
        guard let data = try? JSONEncoder().encode(secret) else { throw .keychain(status: errSecParam) }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // Playback carries on in the background with the screen locked.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query() as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            status = SecItemAdd(query().merging(attributes) { $1 } as CFDictionary, nil)
        }

        guard status == errSecSuccess else { throw .keychain(status: status) }
    }
}
