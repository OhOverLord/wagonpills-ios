import SwiftUI

struct SettingsView: View {
    @Environment(AuthState.self) private var authState
    let authRepository: any AuthRepository
    let prescriptionRepository: any PrescriptionRepository
    let visitRepository: any VisitRepository

    var body: some View {
        NavigationStack {
            List {
                Section("Records") {
                    NavigationLink("Prescriptions") {
                        PrescriptionListView(viewModel: PrescriptionListViewModel(
                            repository: prescriptionRepository,
                            visitRepository: visitRepository
                        ))
                    }
                }

                Section("Account") {
                    if case .signedIn(let email) = authState.status {
                        LabeledContent("Signed in as", value: email)
                    }
                    Button("Sign Out", role: .destructive) {
                        Task { await signOut() }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("More")
        }
    }

    private func signOut() async {
        // Best-effort: revoke the refresh token server-side before clearing
        // local state. Sign-out proceeds regardless of network outcome because
        // access tokens expire on their own and a stranded refresh token is
        // low risk compared to blocking the user in the app.
        if let tokens = authState.currentTokens() {
            try? await authRepository.logout(refreshToken: tokens.refreshToken)
        }
        authState.signOut()
    }
}

#Preview("Signed in") {
    SettingsView(
        authRepository: PreviewAuthRepository(),
        prescriptionRepository: PreviewPrescriptionRepository(),
        visitRepository: PreviewVisitRepository()
    )
    .environment(AuthState.preview(signedIn: "user@example.com"))
}

#Preview("Signed out") {
    SettingsView(
        authRepository: PreviewAuthRepository(),
        prescriptionRepository: PreviewPrescriptionRepository(),
        visitRepository: PreviewVisitRepository()
    )
    .environment(AuthState.previewSignedOut())
}
