import SwiftUI

struct RootView: View {
    var body: some View {
        // Sprint 1: just main tab view.
        // Sprint 2: switch between MainTabView and AuthFlow based on AuthService.state.
        MainTabView()
    }
}

#Preview {
    RootView()
}
