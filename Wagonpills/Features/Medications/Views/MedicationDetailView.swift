import SwiftUI

struct MedicationDetailView: View {
    @State private var vm: MedicationDetailViewModel
    @State private var reminderVM: ReminderListViewModel
    @State private var changesVM: MedicationChangesViewModel
    @State private var editingMedication: Medication?

    init(viewModel: MedicationDetailViewModel) {
        _vm = State(wrappedValue: viewModel)
        _reminderVM = State(wrappedValue: ReminderListViewModel(
            medicationId: viewModel.medicationId,
            repository: viewModel.reminderRepository
        ))
        _changesVM = State(wrappedValue: MedicationChangesViewModel(
            medicationId: viewModel.medicationId,
            repository: viewModel.repository
        ))
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
            content: { med in MedicationEditView(mode: .edit(med), repository: vm.repository, catalogRepository: vm.catalogRepository) }
        )
        .task {
            await vm.load()
            await reminderVM.load()
            await changesVM.load()
        }
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
                remindersSection(med)
                stockSection(med)
                historySection(med)
                changesSection(med)
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

    private func remindersSection(_ med: Medication) -> some View {
        SectionCard(title: "Reminders") {
            switch reminderVM.state {
            case .idle, .loading:
                ProgressView()
            case .empty:
                Text("No reminders set")
                    .foregroundStyle(.secondary)
            case .loaded(let rules):
                ForEach(rules) { rule in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reminderTitle(rule))
                            .font(.subheadline.bold())
                        if !rule.times.isEmpty {
                            Text(rule.times.map(\.displayString).sorted().joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            case .failed:
                Text("Could not load reminders")
                    .foregroundStyle(.secondary)
            }

            NavigationLink(
                destination: ReminderListView(viewModel: reminderVM)
                    .onDisappear { Task { await reminderVM.refresh() } }
            ) {
                Text("Manage Reminders")
                    .font(.subheadline)
            }
        }
    }

    private func reminderTitle(_ rule: ReminderRule) -> String {
        switch rule.repeatType {
        case .daily:
            return "Daily"
        case .weekly:
            let days = rule.daysOfWeek.sorted().map(\.shortName).joined(separator: ", ")
            return days.isEmpty ? "Weekly" : days
        case .interval:
            return "Every \(rule.intervalDays ?? 1) days"
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
            NavigationLink(destination: StockView(medicationId: med.id, repository: vm.repository)) {
                Text("View Full History")
                    .font(.subheadline)
            }
        }
    }

    private func historySection(_ med: Medication) -> some View {
        SectionCard(title: "History") {
            NavigationLink(destination: IntakeHistoryView(viewModel: IntakeHistoryViewModel(
                medicationId: med.id,
                repository: vm.intakeLogRepository
            ))) {
                Text("View Intake History")
                    .font(.subheadline)
            }
        }
    }

    private func changesSection(_ med: Medication) -> some View {
        SectionCard(title: "Changes") {
            if case .loaded(let changes) = changesVM.listState, let latest = changes.first {
                HStack {
                    Text(latest.changeType.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(changeTypeColor(latest.changeType).opacity(0.15))
                        .foregroundStyle(changeTypeColor(latest.changeType))
                        .clipShape(Capsule())
                    Spacer()
                    Text(latest.changedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink(destination: MedicationChangesView(viewModel: changesVM, currentDosageText: med.dosageText)) {
                Text("View All Changes")
                    .font(.subheadline)
            }
        }
    }

    private func changeTypeColor(_ type: MedicationChangeType) -> Color {
        switch type {
        case .start:          return .green
        case .stop:           return .red
        case .dosageChange:   return .orange
        case .scheduleChange: return .blue
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
            ]),
            reminderRepository: PreviewReminderRepository(
                rules: PreviewReminderRepository.makePreviewRules()
            ),
            intakeLogRepository: PreviewIntakeLogRepository(
                logs: PreviewIntakeLogRepository.makeSampleLogs(medicationId: 1)
            ),
            catalogRepository: PreviewCatalogRepository()
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
            ]),
            reminderRepository: PreviewReminderRepository(),
            intakeLogRepository: PreviewIntakeLogRepository(),
            catalogRepository: PreviewCatalogRepository()
        ))
    }
}
