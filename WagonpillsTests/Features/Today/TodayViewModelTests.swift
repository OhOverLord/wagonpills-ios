import Foundation
import Testing
@testable import Wagonpills

@Suite("TodayViewModel")
@MainActor
struct TodayViewModelTests {
    // MARK: - Helpers

    private struct TestSetup {
        let vm: TodayViewModel
        let logRepo: MockIntakeLogRepository
        let rescheduler: MockNotificationRescheduler
    }

    private static let calendar = Calendar.current

    private static func makeSetup(
        medications: [Medication] = [],
        rules: [ReminderRule] = [],
        logs: [IntakeLog] = [],
        logIntakeResult: Result<IntakeLog, Error>? = nil,
        rescheduler: MockNotificationRescheduler = MockNotificationRescheduler()
    ) -> TestSetup {
        let medRepo = MockMedicationRepository()
        medRepo.fetchAllResult = .success(medications)

        let reminderRepo = MockReminderRepository()
        reminderRepo.fetchRulesResult = .success(rules)

        let logRepo = MockIntakeLogRepository()
        logRepo.fetchLogsResult = .success(logs)
        if let result = logIntakeResult {
            logRepo.logIntakeResult = result
        }

        let vm = TodayViewModel(
            medicationRepository: medRepo,
            reminderRepository: reminderRepo,
            intakeLogRepository: logRepo,
            notificationRescheduler: rescheduler
        )
        return TestSetup(vm: vm, logRepo: logRepo, rescheduler: rescheduler)
    }

    private static func makeDailyRule(times: [ReminderTime]) -> ReminderRule {
        ReminderRule(id: 1, repeatType: .daily, intervalDays: nil, daysOfWeek: [], active: true, times: times)
    }

    private static func todayTime(hour: Int, minute: Int = 0) -> Date {
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .init(hour: hour, minute: minute), to: start) ?? Date()
    }

    // MARK: - load()

    @Test("load with one DAILY rule and one time produces one TodayDose")
    func loadOneDailyRuleOneTime() async throws {
        let time = ReminderTime(id: 1, hour: 8, minute: 0)
        let rule = Self.makeDailyRule(times: [time])
        let med = MockMedicationRepository.makeTestMedication()
        let setup = Self.makeSetup(medications: [med], rules: [rule])

        await setup.vm.load()

        guard case .loaded(let doses) = setup.vm.state else {
            Issue.record("Expected .loaded, got \(setup.vm.state)")
            return
        }
        #expect(doses.count == 1)
        #expect(doses[0].medicationId == med.id)
    }

    @Test("load with no medications produces .empty state")
    func loadNoMedications() async {
        let setup = Self.makeSetup(medications: [])
        await setup.vm.load()
        #expect(setup.vm.state == .empty)
    }

    @Test("load with active medication but no active rules produces .empty state")
    func loadNoActiveRules() async {
        let med = MockMedicationRepository.makeTestMedication()
        let inactiveRule = ReminderRule(
            id: 1, repeatType: .daily, intervalDays: nil, daysOfWeek: [], active: false,
            times: [ReminderTime(id: 1, hour: 8, minute: 0)]
        )
        let setup = Self.makeSetup(medications: [med], rules: [inactiveRule])
        await setup.vm.load()
        #expect(setup.vm.state == .empty)
    }

    // MARK: - markTaken()

    @Test("markTaken sets loggingId to nil after completion")
    func markTakenClearsLoggingId() async {
        let scheduledTime = Self.todayTime(hour: 20)
        let time = ReminderTime(id: 1, hour: 20, minute: 0)
        let rule = Self.makeDailyRule(times: [time])
        let med = MockMedicationRepository.makeTestMedication()
        let log = MockIntakeLogRepository.makeLog(medicationId: med.id, scheduledTime: scheduledTime, status: .taken)
        let setup = Self.makeSetup(
            medications: [med],
            rules: [rule],
            logIntakeResult: .success(log)
        )

        await setup.vm.load()
        guard case .loaded(let doses) = setup.vm.state, let dose = doses.first else {
            Issue.record("Expected loaded dose")
            return
        }
        await setup.vm.markTaken(dose, note: nil)
        #expect(setup.vm.loggingId == nil)
    }

    @Test("markTaken success updates the matching dose so dose.log != nil")
    func markTakenSuccessUpdatesLog() async {
        let scheduledTime = Self.todayTime(hour: 20)
        let time = ReminderTime(id: 1, hour: 20, minute: 0)
        let rule = Self.makeDailyRule(times: [time])
        let med = MockMedicationRepository.makeTestMedication()
        let log = MockIntakeLogRepository.makeLog(medicationId: med.id, scheduledTime: scheduledTime, status: .taken)
        let setup = Self.makeSetup(medications: [med], rules: [rule], logIntakeResult: .success(log))

        await setup.vm.load()
        guard case .loaded(let doses) = setup.vm.state, let dose = doses.first else {
            Issue.record("Expected loaded dose")
            return
        }
        await setup.vm.markTaken(dose, note: nil)

        guard case .loaded(let updatedDoses) = setup.vm.state else {
            Issue.record("Expected .loaded after markTaken")
            return
        }
        #expect(updatedDoses.first?.log != nil)
        #expect(updatedDoses.first?.log?.status == .taken)
    }

    @Test("markTaken success triggers notification rescheduling")
    func markTakenSuccessTriggersReschedule() async {
        let scheduledTime = Self.todayTime(hour: 20)
        let time = ReminderTime(id: 1, hour: 20, minute: 0)
        let rule = Self.makeDailyRule(times: [time])
        let med = MockMedicationRepository.makeTestMedication()
        let log = MockIntakeLogRepository.makeLog(medicationId: med.id, scheduledTime: scheduledTime, status: .taken)
        let rescheduler = MockNotificationRescheduler()
        let setup = Self.makeSetup(
            medications: [med], rules: [rule],
            logIntakeResult: .success(log), rescheduler: rescheduler
        )

        await setup.vm.load()
        guard case .loaded(let doses) = setup.vm.state, let dose = doses.first else {
            Issue.record("Expected loaded dose")
            return
        }
        await setup.vm.markTaken(dose, note: nil)
        await Task.yield()
        await Task.yield()

        #expect(rescheduler.rescheduleCallCount >= 1)
        #expect(rescheduler.lastRescheduledMedicationId == med.id)
    }

    @Test("markSkipped success updates the matching dose so dose.log != nil")
    func markSkippedSuccessUpdatesLog() async {
        let scheduledTime = Self.todayTime(hour: 20)
        let time = ReminderTime(id: 1, hour: 20, minute: 0)
        let rule = Self.makeDailyRule(times: [time])
        let med = MockMedicationRepository.makeTestMedication()
        let log = MockIntakeLogRepository.makeLog(medicationId: med.id, scheduledTime: scheduledTime, status: .skipped)
        let setup = Self.makeSetup(medications: [med], rules: [rule], logIntakeResult: .success(log))

        await setup.vm.load()
        guard case .loaded(let doses) = setup.vm.state, let dose = doses.first else {
            Issue.record("Expected loaded dose")
            return
        }
        await setup.vm.markSkipped(dose, note: nil)

        guard case .loaded(let updatedDoses) = setup.vm.state else {
            Issue.record("Expected .loaded after markSkipped")
            return
        }
        #expect(updatedDoses.first?.log?.status == .skipped)
    }

    @Test("markSkipped success triggers notification rescheduling")
    func markSkippedSuccessTriggersReschedule() async {
        let scheduledTime = Self.todayTime(hour: 20)
        let time = ReminderTime(id: 1, hour: 20, minute: 0)
        let rule = Self.makeDailyRule(times: [time])
        let med = MockMedicationRepository.makeTestMedication()
        let log = MockIntakeLogRepository.makeLog(medicationId: med.id, scheduledTime: scheduledTime, status: .skipped)
        let rescheduler = MockNotificationRescheduler()
        let setup = Self.makeSetup(
            medications: [med], rules: [rule],
            logIntakeResult: .success(log), rescheduler: rescheduler
        )

        await setup.vm.load()
        guard case .loaded(let doses) = setup.vm.state, let dose = doses.first else {
            Issue.record("Expected loaded dose")
            return
        }
        await setup.vm.markSkipped(dose, note: nil)
        await Task.yield()
        await Task.yield()

        #expect(rescheduler.rescheduleCallCount >= 1)
    }

    @Test("markTaken network failure sets actionError, keeps dose without log, does not reschedule")
    func markTakenNetworkFailureSetsActionError() async {
        let scheduledTime = Self.todayTime(hour: 20)
        let time = ReminderTime(id: 1, hour: 20, minute: 0)
        let rule = Self.makeDailyRule(times: [time])
        let med = MockMedicationRepository.makeTestMedication()
        let rescheduler = MockNotificationRescheduler()
        let setup = Self.makeSetup(
            medications: [med], rules: [rule],
            logIntakeResult: .failure(APIError.network),
            rescheduler: rescheduler
        )
        _ = scheduledTime

        await setup.vm.load()
        guard case .loaded(let doses) = setup.vm.state, let dose = doses.first else {
            Issue.record("Expected loaded dose")
            return
        }
        await setup.vm.markTaken(dose, note: nil)
        await Task.yield()
        await Task.yield()

        #expect(setup.vm.actionError == .network)
        guard case .loaded(let updatedDoses) = setup.vm.state else {
            Issue.record("Expected still loaded")
            return
        }
        #expect(updatedDoses.first?.log == nil)
        #expect(rescheduler.rescheduleCallCount == 0)
    }

    @Test("markTaken 409 conflict does not crash and refreshes the list")
    func markTakenConflictRefreshesList() async {
        let time = ReminderTime(id: 1, hour: 20, minute: 0)
        let rule = Self.makeDailyRule(times: [time])
        let med = MockMedicationRepository.makeTestMedication()
        let setup = Self.makeSetup(
            medications: [med], rules: [rule],
            logIntakeResult: .failure(APIError.conflict(message: nil))
        )

        await setup.vm.load()
        guard case .loaded(let doses) = setup.vm.state, let dose = doses.first else {
            Issue.record("Expected loaded dose")
            return
        }
        await setup.vm.markTaken(dose, note: nil)

        switch setup.vm.state {
        case .loaded, .empty:
            break
        default:
            Issue.record("Expected .loaded or .empty after 409 conflict, got \(setup.vm.state)")
        }
    }
}
