import SwiftUI

struct PrescriptionEditView: View {
    @State private var vm: PrescriptionEditViewModel
    @State private var showingAddItem = false
    @Environment(\.dismiss) private var dismiss

    let availableVisits: [Visit]

    init(mode: PrescriptionEditViewModel.Mode, repository: any PrescriptionRepository, availableVisits: [Visit] = []) {
        _vm = State(wrappedValue: PrescriptionEditViewModel(mode: mode, repository: repository))
        self.availableVisits = availableVisits
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    Toggle("Has issued date", isOn: Binding(
                        get: { vm.issuedAt != nil },
                        set: { vm.issuedAt = $0 ? Date() : nil }
                    ))
                    if vm.issuedAt != nil {
                        DatePicker(
                            "Issued date",
                            selection: Binding(
                                get: { vm.issuedAt ?? Date() },
                                set: { vm.issuedAt = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                }

                Section("Visit") {
                    if case .edit = vm.mode {
                        if let visitId = vm.doctorVisitId,
                           let visit = availableVisits.first(where: { $0.id == visitId }) {
                            LabeledContent("Linked visit", value: visitLabel(visit))
                        } else if vm.doctorVisitId != nil {
                            LabeledContent("Linked visit", value: "Visit #\(vm.doctorVisitId ?? 0)")
                        } else {
                            Text("No linked visit")
                                .foregroundStyle(.secondary)
                        }
                        Text("Visit cannot be changed after creation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        if availableVisits.isEmpty {
                            Text("No visits available")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Linked visit", selection: $vm.doctorVisitId) {
                                Text("None").tag(Optional<Int64>.none)
                                ForEach(availableVisits) { visit in
                                    Text(visitLabel(visit)).tag(Optional(visit.id))
                                }
                            }
                        }
                    }
                }

                Section("Note") {
                    TextField("Note (optional)", text: $vm.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if case .create = vm.mode {
                    Section {
                        ForEach(vm.pendingItems) { item in
                            DraftItemRow(item: item)
                        }
                        .onDelete { vm.removeDraftItems(at: $0) }
                        Button {
                            showingAddItem = true
                        } label: {
                            Label("Add Medication", systemImage: "plus")
                        }
                    } header: {
                        Text("Medications")
                    }
                }

                if case .failed(let error) = vm.saveState {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(vm.mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await vm.save() }
                    }
                    .disabled(vm.saveState == .saving)
                }
            }
            .onChange(of: vm.saveState) { _, newState in
                if newState == .saved { dismiss() }
            }
            .sheet(isPresented: $showingAddItem) {
                AddDraftItemSheet { item in
                    vm.addDraftItem(item)
                }
            }
        }
    }

    private func visitLabel(_ visit: Visit) -> String {
        let date = visit.visitAt.formatted(date: .abbreviated, time: .omitted)
        if let doctor = visit.doctorName {
            return "\(doctor) — \(date)"
        }
        return date
    }
}

// MARK: - Draft item row

private struct DraftItemRow: View {
    let item: PrescriptionEditViewModel.DraftItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.medicationName)
                .font(.body)
            if let dosage = item.dosageText {
                Text(dosage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add draft item sheet

private struct AddDraftItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (PrescriptionEditViewModel.DraftItem) -> Void

    @State private var medicationName = ""
    @State private var dosageText = ""
    @State private var instructions = ""
    @State private var durationDaysText = ""

    private var isSaveDisabled: Bool {
        medicationName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name (required)", text: $medicationName)
                    TextField("Dosage (e.g. 500 mg)", text: $dosageText)
                }
                Section("Instructions") {
                    TextField("Instructions (optional)", text: $instructions, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Duration") {
                    TextField("Days (optional)", text: $durationDaysText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = PrescriptionEditViewModel.DraftItem(
                            medicationName: medicationName.trimmingCharacters(in: .whitespaces),
                            dosageText: dosageText.isEmpty ? nil : dosageText,
                            instructions: instructions.isEmpty ? nil : instructions,
                            durationDays: Int32(durationDaysText)
                        )
                        onAdd(item)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Create") {
    PrescriptionEditView(
        mode: .create,
        repository: PreviewPrescriptionRepository()
    )
}

#Preview("Edit") {
    let prescriptions = PreviewPrescriptionRepository.makeSamplePrescriptions()
    PrescriptionEditView(
        mode: .edit(prescriptions[0]),
        repository: PreviewPrescriptionRepository(prescriptions: prescriptions)
    )
}

#Preview("With visits") {
    let prescriptions = PreviewPrescriptionRepository.makeSamplePrescriptions()
    let visits = PreviewVisitRepository.makeSampleVisits()
    PrescriptionEditView(
        mode: .create,
        repository: PreviewPrescriptionRepository(prescriptions: prescriptions),
        availableVisits: visits
    )
}
