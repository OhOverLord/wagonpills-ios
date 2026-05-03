import SwiftUI

struct MedicationEditView: View {
    @State private var vm: MedicationEditViewModel
    @State private var showDeleteConfirmation = false
    @State private var showCatalogPicker = false
    @Environment(\.dismiss) private var dismiss

    let catalogRepository: any CatalogRepository

    init(
        mode: MedicationEditViewModel.Mode,
        repository: any MedicationRepository,
        catalogRepository: any CatalogRepository
    ) {
        _vm = State(wrappedValue: MedicationEditViewModel(mode: mode, repository: repository))
        self.catalogRepository = catalogRepository
    }

    var body: some View {
        NavigationStack {
            Form {
                if case .failed(let error) = vm.saveState {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                    }
                }
                basicInfoSection
                instructionsSection
                scheduleSection
                dosageSection
                if case .create = vm.mode { stockSection }
                if case .edit = vm.mode {
                    deleteSection
                }
            }
            .navigationTitle(vm.mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .onChange(of: vm.saveState) { _, new in
                if new == .saved { dismiss() }
            }
            .sheet(isPresented: $showCatalogPicker) {
                CatalogPickerView(repository: catalogRepository) { item in
                    vm.prefillFromCatalog(item)
                }
            }
            .alert(
                "Delete Failed",
                isPresented: Binding(
                    get: { vm.deleteError != nil },
                    set: { if !$0 { vm.deleteError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { vm.deleteError = nil }
            } message: {
                Text(vm.deleteError?.localizedDescription ?? "")
            }
        }
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        Section("Basic Info") {
            TextField("Medication name", text: $vm.name)
            TextField("e.g. 500 mg", text: $vm.dosageText)
                .autocorrectionDisabled()
            if case .create = vm.mode {
                Button {
                    showCatalogPicker = true
                } label: {
                    Label("Search Catalogue", systemImage: "magnifyingglass")
                        .font(.subheadline)
                }
            }
            if case .edit = vm.mode {
                Toggle("Active", isOn: $vm.isActive)
            }
        }
    }

    private var instructionsSection: some View {
        Section("Instructions") {
            TextField("Instructions", text: $vm.instructions, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            DatePicker("Start date", selection: $vm.startDate, displayedComponents: .date)
            Toggle("Set end date", isOn: $vm.hasEndDate)
            if vm.hasEndDate {
                DatePicker(
                    "End date",
                    selection: Binding(
                        get: { vm.endDate ?? vm.startDate },
                        set: { vm.endDate = $0 }
                    ),
                    in: vm.startDate...,
                    displayedComponents: .date
                )
            }
        }
    }

    private var dosageSection: some View {
        Section("Dosage") {
            Picker("Unit", selection: $vm.stockUnit) {
                Text(StockUnit.tablet.displayName).tag(StockUnit.tablet)
                Text(StockUnit.capsule.displayName).tag(StockUnit.capsule)
                Text(StockUnit.milliliters.displayName).tag(StockUnit.milliliters)
                Text(StockUnit.drops.displayName).tag(StockUnit.drops)
            }
            TextField("Per dose quantity", text: $vm.doseQuantity)
                .keyboardType(.decimalPad)
        }
    }

    private var stockSection: some View {
        Section("Stock") {
            if case .create = vm.mode {
                TextField("Initial quantity", text: $vm.currentStock)
                    .keyboardType(.decimalPad)
            }
            TextField("Alert when below", text: $vm.lowStockThreshold)
                .keyboardType(.decimalPad)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if vm.isDeleting {
                        ProgressView()
                    } else {
                        Text("Delete Medication")
                    }
                    Spacer()
                }
            }
            .disabled(vm.isDeleting)
            .confirmationDialog(
                "Delete Medication?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await vm.delete() }
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            if vm.saveState == .saving {
                ProgressView()
            } else {
                Button("Save") {
                    Task { await vm.save() }
                }
                .disabled(vm.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Previews

#Preview("Create") {
    MedicationEditView(
        mode: .create,
        repository: PreviewMedicationRepository(),
        catalogRepository: PreviewCatalogRepository()
    )
}

#Preview("Edit") {
    MedicationEditView(
        mode: .edit(Medication(
            id: 1, name: "Metformin", dosageText: "500 mg",
            instructions: "Take after meals",
            startDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            endDate: nil, isActive: true,
            stockUnit: .tablet, doseQuantity: 2, currentStock: 10,
            lowStockThreshold: 5, catalogItemId: nil, regionCode: nil,
            createdAt: Date(), updatedAt: Date()
        )),
        repository: PreviewMedicationRepository(),
        catalogRepository: PreviewCatalogRepository()
    )
}
