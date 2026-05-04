import SwiftUI

struct MedicationChangesView: View {
    @State private var vm: MedicationChangesViewModel
    @State private var showingCreateSheet = false
    private let currentDosageText: String?

    init(viewModel: MedicationChangesViewModel, currentDosageText: String? = nil) {
        _vm = State(wrappedValue: viewModel)
        self.currentDosageText = currentDosageText
    }

    var body: some View {
        Group {
            switch vm.listState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let changes):
                changesList(changes)
            case .failed(let error):
                errorView(error)
            }
        }
        .navigationTitle("Change History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreateSheet = true } label: {
                    Label("Add Change", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
            }
        }
        .sheet(
            isPresented: $showingCreateSheet,
            onDismiss: { vm.resetForm() },
            content: { MedicationChangeCreateSheet(vm: vm, isPresented: $showingCreateSheet, currentDosageText: currentDosageText) }
        )
        .task { await vm.load() }
    }

    private func changesList(_ changes: [MedicationChange]) -> some View {
        Group {
            if changes.isEmpty {
                ContentUnavailableView(
                    "No Changes Recorded",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Tap + to record a treatment change.")
                )
            } else {
                List(changes) { change in
                    MedicationChangeRow(change: change)
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func errorView(_ error: APIError) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Could Not Load Changes",
                systemImage: "wifi.slash",
                description: Text(error.localizedDescription)
            )
            Button("Retry") { Task { await vm.load() } }
                .buttonStyle(.bordered)
        }
    }
}

// MARK: - Row

private struct MedicationChangeRow: View {
    let change: MedicationChange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                changeTypeBadge
                Spacer()
                Text(change.changedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let old = change.oldValue, let new = change.newValue {
                HStack(spacing: 4) {
                    Text(old)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(new)
                        .bold()
                }
                .font(.subheadline)
            } else if let value = change.newValue ?? change.oldValue {
                Text(value)
                    .font(.subheadline)
            }
            if let reason = change.reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var changeTypeBadge: some View {
        Text(change.changeType.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch change.changeType {
        case .start:          return .green
        case .stop:           return .red
        case .dosageChange:   return .orange
        case .scheduleChange: return .blue
        }
    }
}

// MARK: - Create Sheet

private struct MedicationChangeCreateSheet: View {
    @Bindable var vm: MedicationChangesViewModel
    @Binding var isPresented: Bool
    var currentDosageText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Change Type") {
                    Picker("Type", selection: $vm.changeType) {
                        ForEach(MedicationChangeType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if vm.changeType == .dosageChange {
                    Section("Dosage") {
                        LabeledContent("Current dosage", value: vm.oldValue.isEmpty ? "—" : vm.oldValue)
                            .foregroundStyle(.secondary)
                        TextField("New dosage", text: $vm.newValue)
                    }
                }

                Section("Reason (optional)") {
                    TextField("Reason for change", text: $vm.reason, axis: .vertical)
                        .lineLimit(3...6)
                }

                if case .failed(let error) = vm.saveState {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Record Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Group {
                        if case .saving = vm.saveState {
                            ProgressView()
                        } else {
                            Button("Save") {
                                Task { await save() }
                            }
                        }
                    }
                }
            }
            .onAppear { prefillOldValue() }
            .onChange(of: vm.changeType) { prefillOldValue() }
        }
    }

    private func prefillOldValue() {
        guard vm.changeType == .dosageChange else { return }
        if vm.oldValue.isEmpty {
            vm.oldValue = currentDosageText ?? ""
        }
    }

    private func save() async {
        await vm.createChange()
        if case .saved = vm.saveState {
            isPresented = false
        }
    }
}

// MARK: - Previews

#Preview("With Changes") {
    NavigationStack {
        MedicationChangesView(viewModel: MedicationChangesViewModel(
            medicationId: 1,
            repository: PreviewMedicationRepository(medications: [
                Medication(
                    id: 1, name: "Metformin", dosageText: "500 mg",
                    instructions: nil,
                    startDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
                    endDate: nil, isActive: true, stockUnit: .tablet,
                    doseQuantity: 2, currentStock: nil, lowStockThreshold: nil,
                    catalogItemId: nil, regionCode: nil,
                    createdAt: Date(), updatedAt: Date()
                )
            ])
        ))
    }
}

#Preview("Empty State") {
    NavigationStack {
        MedicationChangesView(viewModel: MedicationChangesViewModel(
            medicationId: 99,
            repository: PreviewMedicationRepository()
        ))
    }
}

#Preview("Create Sheet") {
    MedicationChangeCreateSheet(
        vm: MedicationChangesViewModel(
            medicationId: 1,
            repository: PreviewMedicationRepository()
        ),
        isPresented: .constant(true)
    )
}
