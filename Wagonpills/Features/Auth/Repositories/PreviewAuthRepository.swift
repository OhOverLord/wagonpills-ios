import Foundation

// Stub repository for SwiftUI Previews. Never used in production.
struct PreviewAuthRepository: AuthRepository {
    var loginError: APIError?
    var registerError: APIError?

    private let canned = TokenPair(
        accessToken: "preview-access",
        refreshToken: "preview-refresh",
        email: "preview@example.com"
    )

    func login(email: String, password: String) async throws -> TokenPair {
        if let error = loginError { throw error }
        return canned
    }

    func register(email: String, password: String, preferredRegionCode: String?) async throws -> TokenPair {
        if let error = registerError { throw error }
        return canned
    }

    func refresh(using refreshToken: String) async throws -> TokenPair { canned }
    func logout(refreshToken: String) async throws {}
}
