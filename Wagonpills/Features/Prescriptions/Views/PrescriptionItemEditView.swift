import SwiftUI

struct PrescriptionItemEditView: View {
    @State private var vm: PrescriptionItemEditViewModel
    @Environment(\.dismiss) private var dismiss

    init(mode: PrescriptionItemEditViewModel.Mode, repository: any PrescriptionRepository) {
        _vm = State(wrappedValue: PrescriptionItemEditViewModel(mode: mode, repository: repository))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name (required)", text: $vm.medicationName)
                    TextField("Dosage (e.g. 500 mg)", text: $vm.dosageText)
                }
                Section("Instructions") {
                    TextField("Instructions (optional)", text: $vm.instructions, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Duration") {
                    TextField("Days (optional)", text: $vm.durationDaysText)
                        .keyboardType(.numberPad)
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
                    .disabled(vm.isSaveDisabled || vm.saveState == .saving)
                }
            }
            .onChange(of: vm.saveState) { _, newState in
                if newState == .saved { dismiss() }
            }
        }
    }
}

// MARK: - Previews

#Preview("Create") {
    PrescriptionItemEditView(
        mode: .create(prescriptionId: 1),
        repository: PreviewPrescriptionRepository()
    )
}

#Preview("Edit") {
    let prescriptions = PreviewPrescriptionRepository.makeSamplePrescriptions()
    let item = prescriptions[0].items[0]
    PrescriptionItemEditView(
        mode: .edit(item),
        repository: PreviewPrescriptionRepository(prescriptions: prescriptions)
    )
}
