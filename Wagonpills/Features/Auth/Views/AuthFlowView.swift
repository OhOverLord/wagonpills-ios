import SwiftUI

struct AuthFlowView: View {
    let repository: any AuthRepository
    let authState: AuthState

    var body: some View {
        NavigationStack {
            LoginView(repository: repository, authState: authState)
        }
    }
}

#Preview {
    AuthFlowView(
        repository: PreviewAuthRepository(),
        authState: .previewSignedOut()
    )
}
