import Foundation
import Testing
@testable import Wagonpills

@Suite("LoginViewModel")
@MainActor
struct LoginViewModelTests {
    private let validEmail = "user@example.com"
    private let validPassword = "password123"

    private func makeVM(
        loginResult: Result<TokenPair, Error> = .success(
            TokenPair(accessToken: "a", refreshToken: "r", email: "user@example.com")
        )
    ) -> (LoginViewModel, MockTokenStore) {
        let store = MockTokenStore()
        let repo = MockAuthRepository()
        repo.loginResult = loginResult
        let authState = AuthState(tokenStore: store)
        return (LoginViewModel(repository: repo, authState: authState), store)
    }

    // MARK: Validation

    @Test("isInputValid is false when fields are empty")
    func validationEmptyFields() {
        let (vm, _) = makeVM()
        #expect(vm.isInputValid == false)
    }

    @Test("isInputValid is false for email without @")
    func validationBadEmail() {
        let (vm, _) = makeVM()
        vm.email = "notanemail"
        vm.password = validPassword
        #expect(vm.isInputValid == false)
        #expect(vm.emailError != nil)
    }

    @Test("isInputValid is false for short password")
    func validationShortPassword() {
        let (vm, _) = makeVM()
        vm.email = validEmail
        vm.password = "short"
        #expect(vm.isInputValid == false)
        #expect(vm.passwordError != nil)
    }

    @Test("isInputValid is true for valid email and password >= 8 chars")
    func validationHappyPath() {
        let (vm, _) = makeVM()
        vm.email = validEmail
        vm.password = validPassword
        #expect(vm.isInputValid == true)
        #expect(vm.emailError == nil)
        #expect(vm.passwordError == nil)
    }

    // MARK: Submit — happy path

    @Test("submit transitions through submitting and stores token pair")
    func submitHappyPath() async throws {
        let pair = TokenPair(accessToken: "tok-a", refreshToken: "tok-r", email: validEmail)
        let (vm, store) = makeVM(loginResult: .success(pair))
        vm.email = validEmail
        vm.password = validPassword

        await vm.submit()

        #expect(vm.state == .idle)
        #expect(try store.loadTokens() == pair)
    }

    // MARK: Submit — 401

    @Test("submit on 401 sets .failed(.unauthorized)")
    func submitUnauthorized() async {
        let (vm, _) = makeVM(loginResult: .failure(APIError.unauthorized))
        vm.email = validEmail
        vm.password = validPassword

        await vm.submit()

        #expect(vm.state == .failed(.unauthorized))
    }

    // MARK: Submit — network error

    @Test("submit on network error sets .failed(.network)")
    func submitNetworkError() async {
        let (vm, _) = makeVM(loginResult: .failure(URLError(.notConnectedToInternet)))
        vm.email = validEmail
        vm.password = validPassword

        await vm.submit()

        #expect(vm.state == .failed(.network))
    }

    // MARK: clearError

    @Test("clearError resets .failed to .idle")
    func clearError() async {
        let (vm, _) = makeVM(loginResult: .failure(APIError.unauthorized))
        vm.email = validEmail
        vm.password = validPassword
        await vm.submit()

        vm.clearError()

        #expect(vm.state == .idle)
    }
}
