import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    enum State: Equatable {
        case loading
        case loaded([TodayDose])
        case empty
        case failed(APIError)
    }

    private(set) var state: State = .loading
    private(set) var loggingId: String?
    var actionError: APIError?

    private let medicationRepository: any MedicationRepository
    private let reminderRepository: any ReminderRepository
    private let intakeLogRepository: any IntakeLogRepository
    private let notificationRescheduler: any NotificationRescheduler

    init(
        medicationRepository: any MedicationRepository,
        reminderRepository: any ReminderRepository,
        intakeLogRepository: any IntakeLogRepository,
        notificationRescheduler: any NotificationRescheduler
    ) {
        self.medicationRepository = medicationRepository
        self.reminderRepository = reminderRepository
        self.intakeLogRepository = intakeLogRepository
        self.notificationRescheduler = notificationRescheduler
    }

    func load() async {
        // Keep the existing list visible on pull-to-refresh; only show spinner on first load.
        if case .loaded = state {} else { state = .loading }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        do {
            let medications = try await medicationRepository.fetchAll(activeOnly: true)
            let allDoses = try await buildDoses(medications: medications, startOfDay: startOfDay, calendar: calendar)
            let logs = try await intakeLogRepository.fetchLogs(
                medicationId: nil,
                from: startOfDay,
                to: endOfDay,
                status: nil
            )
            let merged = merge(doses: allDoses, logs: logs)
            state = merged.isEmpty ? .empty : .loaded(merged)
        } catch let error as APIError {
            handleLoadError(error)
        } catch {
            handleLoadError(APIError.from(error))
        }
    }

    func markTaken(_ dose: TodayDose, note: String?) async {
        await mark(dose, status: .taken, note: note)
    }

    func markSkipped(_ dose: TodayDose, note: String?) async {
        await mark(dose, status: .skipped, note: note)
    }
}

// MARK: - Private

private extension TodayViewModel {
    func buildDoses(
        medications: [Medication],
        startOfDay: Date,
        calendar: Calendar
    ) async throws -> [TodayDose] {
        let reminderRepo = reminderRepository
        return try await withThrowingTaskGroup(of: [TodayDose].self) { group in
            for medication in medications {
                let med = medication
                group.addTask {
                    let rules = try await reminderRepo.fetchRules(medicationId: med.id)
                    return rules
                        .filter { $0.active }
                        .flatMap { rule in
                            ScheduledDoseBuilder.build(
                                medicationId: med.id,
                                medicationName: med.name,
                                rule: rule,
                                from: startOfDay,
                                days: 1,
                                calendar: calendar
                            )
                            .compactMap { scheduledDose -> TodayDose? in
                                guard let fireDate = calendar.date(from: scheduledDose.fireDate) else { return nil }
                                // Skip doses scheduled before the medication was created so a
                                // newly added medication never shows false "Missed" entries for
                                // times that passed before it existed.
                                guard fireDate >= med.createdAt else { return nil }
                                return TodayDose(
                                    id: "\(scheduledDose.medicationId).\(scheduledDose.ruleId).\(scheduledDose.timeId)",
                                    medicationId: med.id,
                                    medicationName: med.name,
                                    scheduledTime: fireDate,
                                    doseQuantity: med.doseQuantity,
                                    stockUnit: med.stockUnit,
                                    log: nil
                                )
                            }
                        }
                }
            }
            var all: [TodayDose] = []
            for try await batch in group { all.append(contentsOf: batch) }
            return all
        }
    }

    func merge(doses: [TodayDose], logs: [IntakeLog]) -> [TodayDose] {
        doses
            .map { dose in
                var merged = dose
                merged.log = logs.first {
                    $0.medicationId == dose.medicationId &&
                    abs($0.scheduledTime.timeIntervalSince(dose.scheduledTime)) < 60
                }
                return merged
            }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    func mark(_ dose: TodayDose, status: IntakeStatus, note: String?) async {
        loggingId = dose.id
        defer { loggingId = nil }

        do {
            let log = try await intakeLogRepository.logIntake(
                medicationId: dose.medicationId,
                scheduledTime: dose.scheduledTime,
                status: status,
                note: note
            )
            applyLog(log, toDoseWithId: dose.id)
            rescheduleAsync(medicationId: dose.medicationId)
        } catch APIError.conflict(_) {
            await load()
            if case .loaded(let doses) = state,
               let refreshed = doses.first(where: { $0.id == dose.id }),
               refreshed.log != nil {
                rescheduleAsync(medicationId: dose.medicationId)
            }
        } catch let error as APIError {
            actionError = error
        } catch {
            actionError = APIError.from(error)
        }
    }

    func applyLog(_ log: IntakeLog, toDoseWithId id: String) {
        guard case .loaded(var doses) = state else { return }
        guard let idx = doses.firstIndex(where: { $0.id == id }) else { return }
        var updatedDose = doses[idx]
        updatedDose.log = log
        doses[idx] = updatedDose
        state = .loaded(doses)
    }

    func rescheduleAsync(medicationId: Int64) {
        let rescheduler = notificationRescheduler
        Task { await rescheduler.rescheduleNotifications(for: medicationId) }
    }

    func handleLoadError(_ error: APIError) {
        if case .loaded = state { actionError = error } else { state = .failed(error) }
    }
}
