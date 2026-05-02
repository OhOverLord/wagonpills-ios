import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    private let repository: any AuthRepository
    private let authState: AuthState

    init(repository: any AuthRepository, authState: AuthState) {
        _viewModel = State(wrappedValue: LoginViewModel(repository: repository, authState: authState))
        self.repository = repository
        self.authState = authState
    }

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            Section {
                TextField("Email", text: $vm.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if let error = viewModel.emailError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                SecureField("Password", text: $vm.password)
                    .textContentType(.password)
                if let error = viewModel.passwordError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if case .failed(let error) = viewModel.state {
                Section {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await viewModel.submit() }
                } label: {
                    if case .submitting = viewModel.state {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!viewModel.isInputValid || viewModel.state == .submitting)
            }

            Section {
                NavigationLink {
                    RegisterView(repository: repository, authState: authState)
                } label: {
                    Text("Don't have an account? **Register**")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Sign In")
        .onChange(of: viewModel.email) { _, _ in viewModel.clearError() }
        .onChange(of: viewModel.password) { _, _ in viewModel.clearError() }
    }
}

#Preview("Idle") {
    NavigationStack {
        LoginView(
            repository: PreviewAuthRepository(),
            authState: .previewSignedOut()
        )
    }
}

#Preview("Error state") {
    NavigationStack {
        LoginView(
            repository: PreviewAuthRepository(loginError: .unauthorized),
            authState: .previewSignedOut()
        )
    }
}
