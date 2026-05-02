import SwiftUI

@main
struct WagonpillsApp: App {
    @State private var deps = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(
                authRepository: deps.authRepository,
                medicationRepository: deps.medicationRepository
            )
            .environment(deps.authState)
        }
    }
}
