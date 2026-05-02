import Foundation
import Testing
@testable import Wagonpills

// MARK: - In-memory mock (used by all layers that depend on TokenStore)

final class MockTokenStore: TokenStore, @unchecked Sendable {
    private var stored: TokenPair?

    nonisolated func loadTokens() throws -> TokenPair? { stored }
    nonisolated func save(_ pair: TokenPair) throws { stored = pair }
    nonisolated func clear() throws { stored = nil }
}

// MARK: - Protocol contract tests (run against MockTokenStore, not real Keychain)
// Real KeychainStore is verified manually on simulator; CI Keychain access is flaky.

@Suite("TokenStore protocol contract")
struct TokenStoreTests {
    private let store = MockTokenStore()

    private let samplePair = TokenPair(
        accessToken: "access-abc",
        refreshToken: "refresh-xyz",
        email: "test@example.com"
    )

    @Test("loadTokens returns nil on empty store")
    func emptyLoad() throws {
        #expect(try store.loadTokens() == nil)
    }

    @Test("save then load round-trips the full pair")
    func roundTrip() throws {
        try store.save(samplePair)
        let loaded = try store.loadTokens()
        #expect(loaded == samplePair)
    }

    @Test("save overwrites an existing pair")
    func overwrite() throws {
        let first = TokenPair(accessToken: "a1", refreshToken: "r1", email: "a@a.com")
        let second = TokenPair(accessToken: "a2", refreshToken: "r2", email: "b@b.com")
        try store.save(first)
        try store.save(second)
        #expect(try store.loadTokens() == second)
    }

    @Test("clear makes loadTokens return nil")
    func clearRemovesTokens() throws {
        try store.save(samplePair)
        try store.clear()
        #expect(try store.loadTokens() == nil)
    }

    @Test("clear on empty store does not throw")
    func clearEmpty() throws {
        #expect(throws: Never.self) { try store.clear() }
    }
}
