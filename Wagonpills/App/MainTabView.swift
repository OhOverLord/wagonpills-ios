import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "checkmark.circle")
                }

            MedicationListView()
                .tabItem {
                    Label("Medications", systemImage: "pills")
                }

            VisitListView()
                .tabItem {
                    Label("Visits", systemImage: "stethoscope")
                }

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
        }
    }
}

#Preview {
    MainTabView()
}
