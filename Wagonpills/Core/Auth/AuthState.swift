import Observation

// @MainActor guarantees all access is on the main actor, making this safe to
// pass across concurrency boundaries (e.g. captured in the APIClient init closure).
@MainActor
@Observable
final class AuthState {
    enum Status: Equatable {
        case unknown
        case signedOut
        case signedIn(email: String)
    }

    private(set) var status: Status = .unknown

    private let tokenStore: any TokenStore

    init(tokenStore: any TokenStore) {
        self.tokenStore = tokenStore
    }

    // Called once from RootView.task. Reads Keychain synchronously and resolves
    // .unknown to either .signedIn or .signedOut.
    func bootstrap() {
        do {
            if let pair = try tokenStore.loadTokens() {
                status = .signedIn(email: pair.email)
            } else {
                status = .signedOut
            }
        } catch {
            // Keychain access failure should not crash the app — treat as signed out.
            status = .signedOut
        }
    }

    // Persists the token pair and transitions to .signedIn.
    // Throws if Keychain save fails (e.g. device storage full) so the caller
    // can surface the error rather than silently losing the pair on next restart.
    func signIn(_ pair: TokenPair) throws {
        try tokenStore.save(pair)
        status = .signedIn(email: pair.email)
    }

    // Clears Keychain and unconditionally transitions to .signedOut.
    // Sign-out is never blocked by a Keychain failure.
    func signOut() {
        try? tokenStore.clear()
        status = .signedOut
    }

    // Exposes the current token pair so callers (e.g. SettingsView) can
    // read the refresh token for a best-effort server-side logout before
    // calling signOut(). Returns nil if no tokens are stored.
    func currentTokens() -> TokenPair? {
        try? tokenStore.loadTokens()
    }
}
