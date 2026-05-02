import Observation

// Single composition root for the app's dependency graph.
// Stored as a @State in WagonpillsApp so it is constructed exactly once
// per process, even if SwiftUI recreates the App struct multiple times.
// All three objects must reference the same AuthState instance — keeping them
// together here prevents the stale-capture bug that would arise from
// constructing them separately in App.init().
@MainActor
@Observable
final class AppDependencies {
    let authState: AuthState
    let authRepository: any AuthRepository
    let medicationRepository: any MedicationRepository

    init() {
        let tokenStore = KeychainStore()
        let state = AuthState(tokenStore: tokenStore)
        let apiClient = APIClient(tokenStore: tokenStore, authState: state)
        self.authState = state
        self.authRepository = LiveAuthRepository(apiClient: apiClient)
        self.medicationRepository = LiveMedicationRepository(
            apiClient: apiClient,
            cache: URLCacheStore()
        )
    }
}
