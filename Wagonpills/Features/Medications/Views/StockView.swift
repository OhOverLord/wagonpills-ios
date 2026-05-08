import SwiftUI

struct StockView: View {
    @State private var vm: StockViewModel
    @State private var showUpdateSheet = false

    private let medicationId: Int64
    private let repository: any MedicationRepository

    init(medicationId: Int64, repository: any MedicationRepository) {
        self.medicationId = medicationId
        self.repository = repository
        _vm = State(wrappedValue: StockViewModel(medicationId: medicationId, repository: repository))
    }

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let summary, let history):
                loadedContent(summary: summary, history: history)
            case .failed(let error):
                errorView(error)
            }
        }
        .navigationTitle("Stock")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.refresh() }
        .sheet(
            isPresented: $showUpdateSheet,
            onDismiss: { Task { await vm.refresh() } },
            content: { StockUpdateView(medicationId: medicationId, repository: repository) }
        )
    }

    private func loadedContent(summary: StockSummary, history: [StockMovement]) -> some View {
        List {
            summarySection(summary)
            historySection(history)
        }
    }

    private func summarySection(_ summary: StockSummary) -> some View {
        Section("Current Stock") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(summary.currentStock.formatted()) \(summary.unit.displayName)(s)")
                    .font(.title2.bold())
                if summary.isLowStock {
                    Label("Low stock", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline)
                        .accessibilityLabel("Low stock warning")
                }
            }
            .padding(.vertical, 4)

            Button("Update Stock") {
                showUpdateSheet = true
            }
        }
    }

    private func historySection(_ history: [StockMovement]) -> some View {
        Section("Movement History") {
            if history.isEmpty {
                Text("No movements recorded")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(history) { movement in
                    MovementRow(movement: movement)
                }
            }
        }
    }

    private func errorView(_ error: APIError) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Could not load stock",
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

// MARK: - Movement row

private struct MovementRow: View {
    let movement: StockMovement

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: movement.movementType.systemImage)
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(movement.movementType.displayName)
                    .font(.subheadline.bold())
                if let note = movement.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(movement.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(quantityText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(iconColor)
        }
        .padding(.vertical, 2)
    }

    private var quantityText: String {
        let qty = movement.quantity
        let unit = movement.unit.displayName
        switch movement.movementType {
        case .add:
            return "+\(qty.formatted()) \(unit)"
        case .consume:
            return "-\(qty.formatted()) \(unit)"
        case .adjust:
            let prefix = qty >= 0 ? "+" : ""
            return "\(prefix)\(qty.formatted()) \(unit)"
        }
    }

    private var iconColor: Color {
        switch movement.movementType {
        case .add:     return .green
        case .consume: return .orange
        case .adjust:  return .blue
        }
    }
}

// MARK: - Previews

#Preview("Loaded with low stock") {
    NavigationStack {
        StockView(
            medicationId: 1,
            repository: PreviewMedicationRepository(medications: [
                Medication(
                    id: 1, name: "Metformin", dosageText: "500 mg",
                    instructions: nil, startDate: Date(), endDate: nil,
                    isActive: true, stockUnit: .tablet, doseQuantity: 2,
                    currentStock: 4, lowStockThreshold: 10,
                    catalogItemId: nil, regionCode: nil,
                    createdAt: Date(), updatedAt: Date()
                )
            ])
        )
    }
}

#Preview("Loaded healthy stock") {
    NavigationStack {
        StockView(
            medicationId: 1,
            repository: PreviewMedicationRepository(medications: [
                Medication(
                    id: 1, name: "Ventolin", dosageText: nil,
                    instructions: nil, startDate: Date(), endDate: nil,
                    isActive: true, stockUnit: .drops, doseQuantity: nil,
                    currentStock: 50, lowStockThreshold: 10,
                    catalogItemId: nil, regionCode: nil,
                    createdAt: Date(), updatedAt: Date()
                )
            ])
        )
    }
}
