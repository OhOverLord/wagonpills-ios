import SwiftUI

struct MedicationListView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Medications",
                systemImage: "pills",
                description: Text("Your medications will appear here.")
            )
            .navigationTitle("Medications")
        }
    }
}

#Preview {
    MedicationListView()
}
