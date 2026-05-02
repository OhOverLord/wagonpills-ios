import Foundation
import Testing
@testable import Wagonpills

@Suite("RegisterViewModel")
@MainActor
struct RegisterViewModelTests {
    private let validEmail = "new@example.com"
    private let validPassword = "password123"

    private struct Fixture {
        let vm: RegisterViewModel
        let repo: MockAuthRepository
        let store: MockTokenStore
    }

    private func makeVM(
        registerResult: Result<TokenPair, Error> = .success(
            TokenPair(accessToken: "a", refreshToken: "r", email: "new@example.com")
        )
    ) -> Fixture {
        let store = MockTokenStore()
        let repo = MockAuthRepository()
        repo.registerResult = registerResult

        let authState = AuthState(tokenStore: store)
        let vm = RegisterViewModel(repository: repo, authState: authState)

        return Fixture(vm: vm, repo: repo, store: store)
    }

    // MARK: Happy path

    @Test("submit on valid input stores token pair")
    func submitHappyPath() async throws {
        let pair = TokenPair(accessToken: "tok-a", refreshToken: "tok-r", email: validEmail)
        let fixture = makeVM(registerResult: .success(pair))

        fixture.vm.email = validEmail
        fixture.vm.password = validPassword

        await fixture.vm.submit()

        #expect(fixture.vm.state == .idle)
        #expect(try fixture.store.loadTokens() == pair)
    }

    // MARK: 409 — email taken

    @Test("submit on conflict sets .failed(.conflict)")
    func submitEmailTaken() async {
        let fixture = makeVM(
            registerResult: .failure(APIError.conflict(message: "Email already registered."))
        )

        fixture.vm.email = validEmail
        fixture.vm.password = validPassword

        await fixture.vm.submit()

        if case .failed(.conflict) = fixture.vm.state {
            // pass
        } else {
            Issue.record("Expected .failed(.conflict), got \(fixture.vm.state)")
        }
    }

    // MARK: regionCode forwarding

    @Test("region code is forwarded to repository")
    func regionCodeForwarded() async throws {
        var capturedRegion: String?

        let store = MockTokenStore()
        let pair = TokenPair(accessToken: "a", refreshToken: "r", email: validEmail)
        let repo = CapturingAuthRepository(pair: pair) {
            capturedRegion = $0
        }

        let authState = AuthState(tokenStore: store)
        let vm = RegisterViewModel(repository: repo, authState: authState)

        vm.email = validEmail
        vm.password = validPassword
        vm.regionCode = "SK"

        await vm.submit()

        #expect(capturedRegion == "SK")
    }

    @Test("empty regionCode sends nil to repository")
    func emptyRegionSendsNil() async throws {
        var capturedRegion: String? = "not-nil"

        let store = MockTokenStore()
        let pair = TokenPair(accessToken: "a", refreshToken: "r", email: validEmail)
        let repo = CapturingAuthRepository(pair: pair) {
            capturedRegion = $0
        }

        let authState = AuthState(tokenStore: store)
        let vm = RegisterViewModel(repository: repo, authState: authState)

        vm.email = validEmail
        vm.password = validPassword
        vm.regionCode = "  "

        await vm.submit()

        #expect(capturedRegion == nil)
    }
}

// MARK: - Test double

private final class CapturingAuthRepository: AuthRepository, @unchecked Sendable {
    private let pair: TokenPair
    private let onRegion: (String?) -> Void

    init(pair: TokenPair, onRegion: @escaping (String?) -> Void) {
        self.pair = pair
        self.onRegion = onRegion
    }

    func login(email: String, password: String) async throws -> TokenPair {
        pair
    }

    func register(
        email: String,
        password: String,
        preferredRegionCode: String?
    ) async throws -> TokenPair {
        onRegion(preferredRegionCode)
        return pair
    }

    func refresh(using refreshToken: String) async throws -> TokenPair {
        pair
    }

    func logout(refreshToken: String) async throws {}
}
