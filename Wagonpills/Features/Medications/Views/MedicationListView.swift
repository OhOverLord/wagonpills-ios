import SwiftUI

struct MedicationListView: View {
    @State private var vm: MedicationListViewModel
    @State private var showCreateSheet = false

    let reminderRepository: any ReminderRepository
    let intakeLogRepository: any IntakeLogRepository
    let catalogRepository: any CatalogRepository

    init(
        viewModel: MedicationListViewModel,
        reminderRepository: any ReminderRepository,
        intakeLogRepository: any IntakeLogRepository,
        catalogRepository: any CatalogRepository
    ) {
        _vm = State(wrappedValue: viewModel)
        self.reminderRepository = reminderRepository
        self.intakeLogRepository = intakeLogRepository
        self.catalogRepository = catalogRepository
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Medications")
                .toolbar {
                    filterButton
                    addButton
                }
                .task { await vm.load() }
                .onChange(of: vm.showActiveOnly) { Task { await vm.load() } }
                .refreshable { await vm.refresh() }
                .sheet(
                    isPresented: $showCreateSheet,
                    onDismiss: { Task { await vm.load() } },
                    content: { MedicationEditView(mode: .create, repository: vm.repository, catalogRepository: catalogRepository) }
                )
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
                repository: vm.repository,
                reminderRepository: reminderRepository,
                intakeLogRepository: intakeLogRepository,
                catalogRepository: catalogRepository
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

    @ToolbarContentBuilder
    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus")
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
            Spacer()
            if isLowStock {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel(Text("Low stock"))
            }
        }
    }

    private var isLowStock: Bool {
        guard let stock = medication.currentStock,
              let threshold = medication.lowStockThreshold else { return false }
        return stock < threshold
    }

    private var subtitleText: String {
        [medication.dosageText, medication.isActive ? "Active" : "Inactive"]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

// MARK: - Previews

#Preview("Loaded") {
    MedicationListView(
        viewModel: MedicationListViewModel(
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
                )
            ])
        ),
        reminderRepository: PreviewReminderRepository(),
        intakeLogRepository: PreviewIntakeLogRepository(),
        catalogRepository: PreviewCatalogRepository()
    )
}

#Preview("Empty") {
    MedicationListView(
        viewModel: MedicationListViewModel(
            repository: PreviewMedicationRepository(medications: [])
        ),
        reminderRepository: PreviewReminderRepository(),
        intakeLogRepository: PreviewIntakeLogRepository(),
        catalogRepository: PreviewCatalogRepository()
    )
}
