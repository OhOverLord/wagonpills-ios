import Foundation
import Observation

@MainActor
@Observable
final class RegisterViewModel {
    enum State: Equatable {
        case idle
        case submitting
        case failed(APIError)
    }

    var email = ""
    var password = ""
    var regionCode = "CZ" // TODO(F12): replace with catalogue region picker

    private(set) var state: State = .idle

    private let repository: any AuthRepository
    private let authState: AuthState

    init(repository: any AuthRepository, authState: AuthState) {
        self.repository = repository
        self.authState = authState
    }

    var isInputValid: Bool { isEmailValid && isPasswordValid }

    var emailError: String? {
        guard !email.isEmpty else { return nil }
        return isEmailValid ? nil : String(localized: "Enter a valid email address.")
    }

    var passwordError: String? {
        guard !password.isEmpty else { return nil }
        return isPasswordValid ? nil : String(localized: "Password must be at least 8 characters.")
    }

    func submit() async {
        guard isInputValid, state != .submitting else { return }
        state = .submitting
        do {
            let region = regionCode.trimmingCharacters(in: .whitespaces)
            let pair = try await repository.register(
                email: email,
                password: password,
                preferredRegionCode: region.isEmpty ? nil : region
            )
            try authState.signIn(pair)
            state = .idle
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(.from(error))
        }
    }

    func clearError() {
        if case .failed = state { state = .idle }
    }

    // MARK: - Private

    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }

    private var isPasswordValid: Bool { password.count >= 8 }
}
