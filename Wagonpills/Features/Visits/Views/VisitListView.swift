import SwiftUI

struct VisitListView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Visits",
                systemImage: "stethoscope",
                description: Text("Doctor visit records will appear here.")
            )
            .navigationTitle("Visits")
        }
    }
}

#Preview {
    VisitListView()
}
