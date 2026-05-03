import Foundation

protocol NotificationRescheduler: Sendable {
    func rescheduleNotifications(for medicationId: Int64) async
    func rescheduleAll(medicationIds: [Int64]) async
}

actor LiveNotificationRescheduler: NotificationRescheduler {
    private let reminderRepository: any ReminderRepository
    private let medicationRepository: any MedicationRepository
    private let scheduler: any NotificationScheduler

    init(
        reminderRepository: any ReminderRepository,
        medicationRepository: any MedicationRepository,
        scheduler: any NotificationScheduler
    ) {
        self.reminderRepository = reminderRepository
        self.medicationRepository = medicationRepository
        self.scheduler = scheduler
    }

    func rescheduleNotifications(for medicationId: Int64) async {
        let reminderRepo = reminderRepository
        let medRepo = medicationRepository

        async let rulesResult = reminderRepo.fetchRules(medicationId: medicationId)
        async let medResult = medRepo.fetchById(medicationId)

        guard let medication = try? await medResult else { return }
        let rules = (try? await rulesResult) ?? []

        let doses = buildDoses(medicationId: medicationId, medicationName: medication.name, rules: rules)
        await scheduler.schedule(doses: doses)
    }

    // Gathers doses for every medication, merges, sorts, and schedules the nearest 64 across all.
    func rescheduleAll(medicationIds: [Int64]) async {
        guard !medicationIds.isEmpty else { return }

        let reminderRepo = reminderRepository
        let medRepo = medicationRepository

        var allDoses: [ScheduledDose] = []
        await withTaskGroup(of: [ScheduledDose].self) { group in
            for medId in medicationIds {
                group.addTask {
                    guard let med = try? await medRepo.fetchById(medId) else { return [] }
                    let rules = (try? await reminderRepo.fetchRules(medicationId: medId)) ?? []
                    return buildDoses(medicationId: medId, medicationName: med.name, rules: rules)
                }
            }
            for await doses in group {
                allDoses.append(contentsOf: doses)
            }
        }

        allDoses.sort { lhs, rhs in
            guard
                let lhsDate = Calendar.current.date(from: lhs.fireDate),
                let rhsDate = Calendar.current.date(from: rhs.fireDate)
            else { return false }
            return lhsDate < rhsDate
        }
        await scheduler.schedule(doses: allDoses)
    }
}

// No-op implementation used as the @Environment default and in previews.
struct NoOpNotificationRescheduler: NotificationRescheduler {
    func rescheduleNotifications(for medicationId: Int64) async {}
    func rescheduleAll(medicationIds: [Int64]) async {}
}

// MARK: - Private helpers

private func buildDoses(medicationId: Int64, medicationName: String, rules: [ReminderRule]) -> [ScheduledDose] {
    let from = Date()
    return rules
        .filter { $0.active }
        .flatMap { rule in
            ScheduledDoseBuilder.build(
                medicationId: medicationId,
                medicationName: medicationName,
                rule: rule,
                from: from,
                days: 30
            )
        }
}
