#if DEBUG
import Foundation

// In-memory token store for SwiftUI Previews. Never shipped in production.
struct PreviewTokenStore: TokenStore {
    var pair: TokenPair?

    nonisolated func loadTokens() throws -> TokenPair? { pair }
    nonisolated func save(_ pair: TokenPair) throws {}
    nonisolated func clear() throws {}
}

extension AuthState {
    // Creates an AuthState that reports .signedIn after bootstrap().
    static func preview(signedIn email: String) -> AuthState {
        let store = PreviewTokenStore(
            pair: TokenPair(accessToken: "preview-access", refreshToken: "preview-refresh", email: email)
        )
        let state = AuthState(tokenStore: store)
        state.bootstrap()
        return state
    }

    // Creates an AuthState that reports .signedOut after bootstrap().
    static func previewSignedOut() -> AuthState {
        let state = AuthState(tokenStore: PreviewTokenStore())
        state.bootstrap()
        return state
    }
}
#endif
