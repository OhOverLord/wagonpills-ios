import SwiftUI

struct CalendarView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Calendar",
                systemImage: "calendar",
                description: Text("Events and reminders will appear here.")
            )
            .navigationTitle("Calendar")
        }
    }
}

#Preview {
    CalendarView()
}
