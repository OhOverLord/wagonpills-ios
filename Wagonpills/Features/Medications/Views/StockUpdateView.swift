import SwiftUI

struct StockUpdateView: View {
    @State private var vm: StockUpdateViewModel
    @Environment(\.dismiss) private var dismiss

    init(medicationId: Int64, repository: any MedicationRepository) {
        _vm = State(wrappedValue: StockUpdateViewModel(medicationId: medicationId, repository: repository))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Operation", selection: $vm.operation) {
                        Text("Add Refill").tag(StockUpdateViewModel.Operation.add)
                        Text("Adjust").tag(StockUpdateViewModel.Operation.adjust)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField(quantityPlaceholder, text: $vm.quantityText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text(quantityHeader)
                } footer: {
                    if vm.operation == .adjust {
                        Text("Use a negative number to reduce stock.")
                            .font(.caption)
                    }
                }

                Section("Note (optional)") {
                    TextField("Reason or description", text: $vm.note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if case .failed(let error) = vm.saveState {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Update Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .onChange(of: vm.saveState) { _, new in
                if new == .saved { dismiss() }
            }
        }
    }

    private var quantityPlaceholder: String {
        vm.operation == .add ? "Units to add" : "Adjustment amount (±)"
    }

    private var quantityHeader: String {
        vm.operation == .add ? "Quantity" : "Quantity (positive or negative)"
    }

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
                .disabled(vm.quantityText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StockUpdateView(
        medicationId: 1,
        repository: PreviewMedicationRepository()
    )
}
