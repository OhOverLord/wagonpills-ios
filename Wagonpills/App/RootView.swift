import SwiftUI

struct RootView: View {
    @Environment(AuthState.self) private var authState
    let authRepository: any AuthRepository
    let medicationRepository: any MedicationRepository

    var body: some View {
        switch authState.status {
        case .unknown:
            SplashView()
                .task { authState.bootstrap() }
        case .signedOut:
            AuthFlowView(repository: authRepository, authState: authState)
        case .signedIn:
            MainTabView(
                authRepository: authRepository,
                medicationRepository: medicationRepository
            )
        }
    }
}

#Preview("Signed out") {
    RootView(
        authRepository: PreviewAuthRepository(),
        medicationRepository: PreviewMedicationRepository()
    )
    .environment(AuthState.previewSignedOut())
}

#Preview("Signed in") {
    RootView(
        authRepository: PreviewAuthRepository(),
        medicationRepository: PreviewMedicationRepository()
    )
    .environment(AuthState.preview(signedIn: "user@example.com"))
}
