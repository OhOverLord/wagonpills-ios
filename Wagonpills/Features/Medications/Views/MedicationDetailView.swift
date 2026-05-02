import SwiftUI

struct MedicationDetailView: View {
    @State private var vm: MedicationDetailViewModel
    @State private var editingMedication: Medication?
    @State private var showStockSheet = false

    init(viewModel: MedicationDetailViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch vm.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let medication):
                medicationContent(medication)
            case .failed(let error):
                errorView(error)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .loaded(let med) = vm.state {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editingMedication = med }
                }
            }
        }
        .sheet(
            item: $editingMedication,
            onDismiss: { Task { await vm.load() } },
            content: { med in MedicationEditView(mode: .edit(med), repository: vm.repository) }
        )
        .sheet(
            isPresented: $showStockSheet,
            onDismiss: { Task { await vm.load() } },
            content: {
                if case .loaded(let med) = vm.state {
                    StockUpdateView(medicationId: med.id, repository: vm.repository)
                }
            }
        )
        .task { await vm.load() }
    }

    private var navigationTitle: String {
        if case .loaded(let med) = vm.state { return med.name }
        return ""
    }

    private func medicationContent(_ med: Medication) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection(med)
                dosageSection(med)
                scheduleSection(med)
                stockSection(med)
                metadataSection(med)
            }
            .padding()
        }
    }

    private func headerSection(_ med: Medication) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(med.name)
                .font(.title2.bold())
            Text(med.isActive ? "Active" : "Inactive")
                .font(.caption.bold())
                .foregroundStyle(med.isActive ? Color.green : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(med.isActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
                )
        }
    }

    private func dosageSection(_ med: Medication) -> some View {
        SectionCard(title: "Dosage") {
            if let dosageText = med.dosageText {
                LabeledContent("Dosage", value: dosageText)
            }
            if let qty = med.doseQuantity {
                LabeledContent("Per dose", value: "\(qty.formatted()) \(med.stockUnit.displayName)(s)")
            }
            if let instructions = med.instructions {
                LabeledContent("Instructions", value: instructions)
            }
        }
    }

    private func scheduleSection(_ med: Medication) -> some View {
        SectionCard(title: "Schedule") {
            LabeledContent("Start date", value: med.startDate.formatted(date: .abbreviated, time: .omitted))
            LabeledContent(
                "End date",
                value: med.endDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Ongoing"
            )
        }
    }

    private func stockSection(_ med: Medication) -> some View {
        SectionCard(title: "Stock") {
            if let stock = med.currentStock {
                HStack {
                    LabeledContent("Current stock", value: "\(stock.formatted()) \(med.stockUnit.displayName)(s)")
                    if let threshold = med.lowStockThreshold, stock < threshold {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            } else {
                Text("Not tracked")
                    .foregroundStyle(.secondary)
            }
            Button("Update Stock") {
                showStockSheet = true
            }
            .font(.subheadline)
        }
    }

    private func metadataSection(_ med: Medication) -> some View {
        SectionCard(title: "Info") {
            LabeledContent("Added", value: med.createdAt.formatted(.relative(presentation: .named)))
        }
    }

    private func errorView(_ error: APIError) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Could not load medication",
                systemImage: "wifi.slash",
                description: Text(error.localizedDescription)
            )
            Button("Retry") {
                Task { await vm.load() }
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - SectionCard helper

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Previews

#Preview("Full") {
    NavigationStack {
        MedicationDetailView(viewModel: MedicationDetailViewModel(
            medicationId: 1,
            repository: PreviewMedicationRepository(medications: [
                Medication(
                    id: 1, name: "Metformin", dosageText: "500 mg",
                    instructions: "Take after meals with water",
                    startDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
                    endDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
                    isActive: true, stockUnit: .tablet,
                    doseQuantity: 2, currentStock: 8, lowStockThreshold: 10,
                    catalogItemId: nil, regionCode: "CZ",
                    createdAt: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
                    updatedAt: Date()
                )
            ])
        ))
    }
}

#Preview("Minimal") {
    NavigationStack {
        MedicationDetailView(viewModel: MedicationDetailViewModel(
            medicationId: 2,
            repository: PreviewMedicationRepository(medications: [
                Medication(
                    id: 2, name: "Ventolin", dosageText: nil, instructions: nil,
                    startDate: Date(), endDate: nil, isActive: true,
                    stockUnit: .drops, doseQuantity: nil, currentStock: nil,
                    lowStockThreshold: nil, catalogItemId: nil, regionCode: nil,
                    createdAt: Date(), updatedAt: Date()
                )
            ])
        ))
    }
}
