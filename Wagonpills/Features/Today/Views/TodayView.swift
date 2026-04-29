import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Today",
                systemImage: "checkmark.circle",
                description: Text("Scheduled doses will appear here.")
            )
            .navigationTitle("Today")
        }
    }
}

#Preview {
    TodayView()
}
