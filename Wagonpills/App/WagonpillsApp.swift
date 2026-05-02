import SwiftUI

@main
struct WagonpillsApp: App {
    @State private var deps = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(authRepository: deps.authRepository)
                .environment(deps.authState)
        }
    }
}
