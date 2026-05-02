import SwiftUI

struct MedicationListView: View {
    @State private var vm: MedicationListViewModel

    init(viewModel: MedicationListViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Medications")
                .toolbar { filterButton }
                .task { await vm.load() }
                .onChange(of: vm.showActiveOnly) { Task { await vm.load() } }
                .refreshable { await vm.refresh() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let medications):
            medicationList(medications)
        case .empty:
            emptyState
        case .failed(let error):
            errorBanner(error)
        }
    }

    private func medicationList(_ medications: [Medication]) -> some View {
        List(medications) { medication in
            NavigationLink(value: medication) {
                MedicationRow(medication: medication)
            }
        }
        .navigationDestination(for: Medication.self) { medication in
            MedicationDetailView(viewModel: MedicationDetailViewModel(
                medicationId: medication.id,
                repository: vm.repository
            ))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No medications yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            if vm.showActiveOnly {
                Button("Show all medications") {
                    vm.showActiveOnly = false
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ error: APIError) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Could not load medications",
                systemImage: "wifi.slash",
                description: Text(error.localizedDescription)
            )
            Button("Retry") {
                Task { await vm.load() }
            }
            .buttonStyle(.bordered)
        }
    }

    @ToolbarContentBuilder
    private var filterButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                vm.showActiveOnly.toggle()
            } label: {
                Label(
                    "Active only",
                    systemImage: vm.showActiveOnly
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                )
            }
        }
    }
}

// MARK: - Row

private struct MedicationRow: View {
    let medication: Medication

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.body)
                HStack(spacing: 4) {
                    Circle()
                        .fill(medication.isActive ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var subtitleText: String {
        [medication.dosageText, medication.isActive ? "Active" : "Inactive"]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

// MARK: - Previews

#Preview("Loaded") {
    MedicationListView(viewModel: MedicationListViewModel(
        repository: PreviewMedicationRepository(medications: [
            Medication(
                id: 1, name: "Metformin", dosageText: "500 mg",
                instructions: "Take after meals",
                startDate: Date(), endDate: nil, isActive: true,
                stockUnit: .tablet, doseQuantity: 2, currentStock: 10,
                lowStockThreshold: 5, catalogItemId: nil, regionCode: nil,
                createdAt: Date(), updatedAt: Date()
            ),
            Medication(
                id: 2, name: "Lisinopril", dosageText: "10 mg",
                instructions: nil,
                startDate: Date(), endDate: Date(), isActive: false,
                stockUnit: .tablet, doseQuantity: 1, currentStock: 3,
                lowStockThreshold: 5, catalogItemId: nil, regionCode: nil,
                createdAt: Date(), updatedAt: Date()
            ),
            Medication(
                id: 3, name: "Ventolin", dosageText: nil,
                instructions: "Inhale as needed",
                startDate: Date(), endDate: nil, isActive: true,
                stockUnit: .drops, doseQuantity: nil, currentStock: nil,
                lowStockThreshold: nil, catalogItemId: nil, regionCode: nil,
                createdAt: Date(), updatedAt: Date()
            )
        ])
    ))
}

#Preview("Empty") {
    MedicationListView(viewModel: MedicationListViewModel(
        repository: PreviewMedicationRepository(medications: [])
    ))
}
