import Foundation
@testable import Wagonpills

final class MockAuthRepository: AuthRepository, @unchecked Sendable {
    var loginResult: Result<TokenPair, Error> = .success(
        TokenPair(accessToken: "a", refreshToken: "r", email: "test@example.com")
    )
    var registerResult: Result<TokenPair, Error> = .success(
        TokenPair(accessToken: "a", refreshToken: "r", email: "test@example.com")
    )

    func login(email: String, password: String) async throws -> TokenPair {
        try loginResult.get()
    }
    func register(email: String, password: String, preferredRegionCode: String?) async throws -> TokenPair {
        try registerResult.get()
    }
    func refresh(using refreshToken: String) async throws -> TokenPair {
        TokenPair(accessToken: "new-a", refreshToken: "new-r", email: "test@example.com")
    }
    func logout(refreshToken: String) async throws {}
}
