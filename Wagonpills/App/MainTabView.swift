import SwiftUI

struct MainTabView: View {
    let authRepository: any AuthRepository

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checkmark.circle") }

            MedicationListView()
                .tabItem { Label("Medications", systemImage: "pills") }

            VisitListView()
                .tabItem { Label("Visits", systemImage: "stethoscope") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            SettingsView(authRepository: authRepository)
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}

#Preview {
    MainTabView(authRepository: PreviewAuthRepository())
        .environment(AuthState.preview(signedIn: "user@example.com"))
}
