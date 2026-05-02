import Foundation
import Testing
@testable import Wagonpills

@Suite("AuthState")
@MainActor
struct AuthStateTests {
    private let pair = TokenPair(
        accessToken: "tok-a",
        refreshToken: "tok-r",
        email: "user@example.com"
    )

    @Test("bootstrap with stored tokens → .signedIn")
    func bootstrapSignedIn() throws {
        let store = MockTokenStore()
        try store.save(pair)
        let state = AuthState(tokenStore: store)
        #expect(state.status == .unknown)
        state.bootstrap()
        #expect(state.status == .signedIn(email: pair.email))
    }

    @Test("bootstrap with empty store → .signedOut")
    func bootstrapSignedOut() {
        let state = AuthState(tokenStore: MockTokenStore())
        state.bootstrap()
        #expect(state.status == .signedOut)
    }

    @Test("bootstrap with failing store → .signedOut, no crash")
    func bootstrapKeychainFailure() {
        let state = AuthState(tokenStore: ThrowingTokenStore())
        state.bootstrap()
        #expect(state.status == .signedOut)
    }

    @Test("signIn saves pair and transitions to .signedIn")
    func signIn() throws {
        let store = MockTokenStore()
        let state = AuthState(tokenStore: store)
        try state.signIn(pair)
        #expect(state.status == .signedIn(email: pair.email))
        #expect(try store.loadTokens() == pair)
    }

    @Test("signOut clears store and transitions to .signedOut")
    func signOut() throws {
        let store = MockTokenStore()
        let state = AuthState(tokenStore: store)
        try state.signIn(pair)
        state.signOut()
        #expect(state.status == .signedOut)
        #expect(try store.loadTokens() == nil)
    }

    @Test("signOut does not throw even if Keychain clear fails")
    func signOutKeychainFailure() {
        let state = AuthState(tokenStore: ThrowingTokenStore())
        state.signOut()
        #expect(state.status == .signedOut)
    }

    @Test("currentTokens returns pair after signIn")
    func currentTokensAfterSignIn() throws {
        let store = MockTokenStore()
        let state = AuthState(tokenStore: store)
        try state.signIn(pair)
        #expect(state.currentTokens() == pair)
    }

    @Test("currentTokens returns nil before signIn")
    func currentTokensBeforeSignIn() {
        let state = AuthState(tokenStore: MockTokenStore())
        #expect(state.currentTokens() == nil)
    }

    @Test("currentTokens returns nil after signOut")
    func currentTokensAfterSignOut() throws {
        let store = MockTokenStore()
        let state = AuthState(tokenStore: store)
        try state.signIn(pair)
        state.signOut()
        #expect(state.currentTokens() == nil)
    }
}

// MARK: - Test doubles

private final class ThrowingTokenStore: TokenStore, @unchecked Sendable {
    nonisolated func loadTokens() throws -> TokenPair? {
        throw APIError.unexpected("simulated Keychain failure")
    }
    nonisolated func save(_ pair: TokenPair) throws {
        throw APIError.unexpected("simulated Keychain failure")
    }
    nonisolated func clear() throws {
        throw APIError.unexpected("simulated Keychain failure")
    }
}
