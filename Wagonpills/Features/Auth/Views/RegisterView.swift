import SwiftUI

struct RegisterView: View {
    @State private var viewModel: RegisterViewModel
    @Environment(\.dismiss) private var dismiss

    init(repository: any AuthRepository, authState: AuthState) {
        _viewModel = State(wrappedValue: RegisterViewModel(repository: repository, authState: authState))
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
                    .textContentType(.newPassword)
                if let error = viewModel.passwordError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // TODO(F12): Replace with a catalogue-backed region picker once
            // the medication catalogue feature is implemented.
            Section(header: Text("Region"), footer: Text("Used to pre-fill the medication catalogue.")) {
                TextField("Region code", text: $vm.regionCode)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
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
                        Text("Create Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!viewModel.isInputValid || viewModel.state == .submitting)
            }

            Section {
                Button {
                    dismiss()
                } label: {
                    Text("Already have an account? **Sign In**")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Create Account")
        .onChange(of: viewModel.email) { _, _ in viewModel.clearError() }
        .onChange(of: viewModel.password) { _, _ in viewModel.clearError() }
    }
}

#Preview("Idle") {
    NavigationStack {
        RegisterView(
            repository: PreviewAuthRepository(),
            authState: .previewSignedOut()
        )
    }
}

#Preview("Email taken error") {
    NavigationStack {
        RegisterView(
            repository: PreviewAuthRepository(registerError: .conflict(message: "Email already registered.")),
            authState: .previewSignedOut()
        )
    }
}
