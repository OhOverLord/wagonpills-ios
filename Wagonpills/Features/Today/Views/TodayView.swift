import SwiftUI

struct TodayView: View {
    @State private var vm: TodayViewModel
    @State private var pendingAction: DoseAction?
    @State private var noteText = ""

    init(viewModel: TodayViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Today")
                .task { await vm.load() }
                .refreshable { await vm.load() }
                .sheet(item: $pendingAction) { action in
                    NoteSheet(
                        doseLabel: action.dose.medicationName,
                        actionLabel: action.kind == .taken ? "Take" : "Skip",
                        note: $noteText
                    ) {
                        let note = noteText.trimmingCharacters(in: .whitespaces)
                        let finalNote = note.isEmpty ? nil : note
                        let dose = action.dose
                        noteText = ""
                        pendingAction = nil
                        Task {
                            if action.kind == .taken {
                                await vm.markTaken(dose, note: finalNote)
                            } else {
                                await vm.markSkipped(dose, note: finalNote)
                            }
                        }
                    } onCancel: {
                        noteText = ""
                        pendingAction = nil
                    }
                }
                .alert(
                    "Error",
                    isPresented: Binding(get: { vm.actionError != nil }, set: { if !$0 { vm.actionError = nil } }),
                    actions: { Button("OK") { vm.actionError = nil } },
                    message: { Text(vm.actionError?.localizedDescription ?? "") }
                )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let doses):
            doseList(doses)
        case .empty:
            emptyState
        case .failed(let error):
            errorView(error)
        }
    }

    private func doseList(_ doses: [TodayDose]) -> some View {
        let now = Date()
        let upcoming = doses.filter { $0.log == nil && $0.scheduledTime > now }
        let missed   = doses.filter { $0.log == nil && $0.scheduledTime <= now }
        let done     = doses.filter { $0.log != nil }

        return List {
            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { dose in
                        UpcomingDoseRow(
                            dose: dose,
                            isLogging: vm.loggingId == dose.id
                        ) { kind in
                            noteText = ""
                            pendingAction = DoseAction(dose: dose, kind: kind)
                        }
                    }
                }
            }
            if !missed.isEmpty {
                Section("Missed") {
                    ForEach(missed) { dose in
                        UpcomingDoseRow(
                            dose: dose,
                            isLogging: vm.loggingId == dose.id
                        ) { kind in
                            noteText = ""
                            pendingAction = DoseAction(dose: dose, kind: kind)
                        }
                    }
                }
            }
            if !done.isEmpty {
                Section("Done") {
                    ForEach(done) { dose in
                        DoneDoseRow(dose: dose)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "All done for today",
            systemImage: "checkmark.circle",
            description: Text("No scheduled doses remain.")
        )
    }

    private func errorView(_ error: APIError) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Could not load schedule",
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

// MARK: - DoseAction

private struct DoseAction: Identifiable {
    enum Kind { case taken, skipped }
    let id = UUID()
    let dose: TodayDose
    let kind: Kind
}

// MARK: - UpcomingDoseRow

private struct UpcomingDoseRow: View {
    let dose: TodayDose
    let isLogging: Bool
    let onAction: (DoseAction.Kind) -> Void

    private var timeLabel: String { Self.timeFormatter.string(from: dose.scheduledTime) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(timeLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(dose.medicationName)
                    .font(.body)
                if let qty = dose.doseQuantity {
                    Text(formatQuantity(qty, unit: dose.stockUnit))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isLogging {
                ProgressView()
                    .controlSize(.small)
            } else {
                HStack(spacing: 8) {
                    Button {
                        onAction(.taken)
                    } label: {
                        Text("Take")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        onAction(.skipped)
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

// MARK: - DoneDoseRow

private struct DoneDoseRow: View {
    let dose: TodayDose

    private var timeLabel: String { Self.timeFormatter.string(from: dose.scheduledTime) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(timeLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(dose.medicationName)
                    .font(.body)
                if let qty = dose.doseQuantity {
                    Text(formatQuantity(qty, unit: dose.stockUnit))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let log = dose.log {
                statusView(for: log.status)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusView(for status: IntakeStatus) -> some View {
        switch status {
        case .taken:
            Label("Taken", systemImage: "checkmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
        case .skipped:
            Label("Skipped", systemImage: "slash.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
        case .missed:
            Label("Missed", systemImage: "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

// MARK: - NoteSheet

private struct NoteSheet: View {
    let doseLabel: String
    let actionLabel: String
    @Binding var note: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("\(actionLabel): \(doseLabel)")
                } footer: {
                    Text("You can leave the note empty.")
                }
            }
            .navigationTitle(actionLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm", action: onConfirm)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Helpers

private func formatQuantity(_ quantity: Double, unit: StockUnit) -> String {
    let qty = quantity.truncatingRemainder(dividingBy: 1) == 0
        ? String(Int(quantity))
        : String(format: "%.1f", quantity)
    return "\(qty) \(unit.displayName)"
}

// MARK: - Previews

#Preview("Today — mixed") {
    let calendar = Calendar.current
    let past    = calendar.date(byAdding: .hour, value: -3, to: Date()) ?? Date()
    let missed  = calendar.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
    let upcoming = calendar.date(byAdding: .hour, value: 2, to: Date()) ?? Date()

    let ruleId: Int64 = 1

    let doses: [TodayDose] = [
        TodayDose(
            id: "1.\(ruleId).1",
            medicationId: 1,
            medicationName: "Lisinopril",
            scheduledTime: past,
            doseQuantity: 1,
            stockUnit: .tablet,
            log: IntakeLog(
                id: 101,
                medicationId: 1,
                scheduledTime: past,
                status: .taken,
                note: nil,
                takenAt: past
            )
        ),
        TodayDose(
            id: "1.\(ruleId).2",
            medicationId: 1,
            medicationName: "Metformin",
            scheduledTime: upcoming,
            doseQuantity: 2,
            stockUnit: .tablet,
            log: nil
        ),
        TodayDose(
            id: "1.\(ruleId).3",
            medicationId: 1,
            medicationName: "Aspirin",
            scheduledTime: missed,
            doseQuantity: 1,
            stockUnit: .tablet,
            log: nil
        )
    ]

    let med = MockMedicationForPreview.medication
    let rule = MockMedicationForPreview.rule(doses: doses)
    let vm = TodayViewModel(
        medicationRepository: PreviewMedicationRepository(medications: [med]),
        reminderRepository: PreviewReminderRepository(rules: [rule]),
        intakeLogRepository: PreviewIntakeLogRepository(logs: doses.compactMap { $0.log }),
        notificationRescheduler: NoOpNotificationRescheduler()
    )

    return TodayView(viewModel: vm)
}

#Preview("Today — empty") {
    let vm = TodayViewModel(
        medicationRepository: PreviewMedicationRepository(medications: []),
        reminderRepository: PreviewReminderRepository(),
        intakeLogRepository: PreviewIntakeLogRepository(),
        notificationRescheduler: NoOpNotificationRescheduler()
    )
    return TodayView(viewModel: vm)
}

// MARK: - Preview helpers

private enum MockMedicationForPreview {
    static var medication: Medication {
        Medication(
            id: 1, name: "Preview Med", dosageText: nil, instructions: nil,
            startDate: Date(), endDate: nil, isActive: true,
            stockUnit: .tablet, doseQuantity: nil,
            currentStock: nil, lowStockThreshold: nil,
            catalogItemId: nil, regionCode: nil,
            createdAt: Date(), updatedAt: Date()
        )
    }

    static func rule(doses: [TodayDose]) -> ReminderRule {
        let calendar = Calendar.current
        let times = doses.enumerated().map { idx, dose in
            ReminderTime(
                id: Int64(idx + 1),
                hour: calendar.component(.hour, from: dose.scheduledTime),
                minute: calendar.component(.minute, from: dose.scheduledTime)
            )
        }
        return ReminderRule(
            id: 1, repeatType: .daily, intervalDays: nil,
            daysOfWeek: [], active: true, times: times
        )
    }
}
