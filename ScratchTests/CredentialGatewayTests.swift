import Foundation
import Security
import Testing
@testable import Scratch

/// Uses the real Keychain and UserDefaults, under a service and suite of its own.
struct CredentialGatewayTests {
    private let environment = AppEnvironment.fresh()
    private var gateway: KeychainCredentialGateway { KeychainCredentialGateway(environment: environment) }

    @Test func roundTripsWithSaltAndTokenOnlyInTheKeychain() throws {
        let gateway = gateway
        defer { try? gateway.delete(); environment.remove() }
        #expect(gateway.load() == nil)

        try gateway.save(.sample)

        #expect(gateway.load() == .sample)
        let stored = environment.defaults.persistentDomain(forName: environment.keychainService)?.values.compactMap { $0 as? String } ?? []
        #expect(Set(stored) == ["https://music.example.com", "me"])

        // The secret is in the Keychain: with defaults restored but the item gone, nothing loads.
        let secretQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: environment.keychainService]
        #expect(SecItemDelete(secretQuery as CFDictionary) == errSecSuccess)
        #expect(gateway.load() == nil)
    }

    @Test func savingAgainReplacesTheServer() throws {
        let gateway = gateway
        defer { try? gateway.delete(); environment.remove() }
        var other = SavedServer.sample
        other.credentials.token = "newer"

        try gateway.save(.sample)
        try gateway.save(other)

        #expect(gateway.load() == other)
    }

    @Test func deleteForgetsEverything() throws {
        let gateway = gateway
        defer { environment.remove() }
        try gateway.save(.sample)

        try gateway.delete()

        #expect(gateway.load() == nil)
        try gateway.delete()
    }
}
