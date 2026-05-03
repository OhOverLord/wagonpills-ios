import Foundation
import Testing
@testable import Wagonpills

@Suite("ReminderRuleEditViewModel")
@MainActor
struct ReminderRuleEditViewModelTests {

    // MARK: - save() in create mode

    @Test("DAILY rule with one time saves successfully")
    func saveDailySuccess() async {
        let repo = MockReminderRepository()
        let createdRule = MockReminderRepository.makeTestRule(id: 10)
        let createdTime = MockReminderRepository.makeTestTime(id: 20)
        repo.createRuleResult = .success(createdRule)
        repo.addTimeResult = .success(createdTime)

        let vm = ReminderRuleEditViewModel(mode: .create, medicationId: 1, repository: repo)
        vm.repeatType = .daily
        vm.addTime(makeComponents(hour: 8, minute: 0))

        await vm.save()

        #expect(vm.saveState == .saved)
        #expect(repo.createRuleCallCount == 1)
        #expect(repo.addTimeCallCount == 1)
    }

    @Test("WEEKLY rule with no days selected fails validation")
    func saveWeeklyNoDaysFails() async {
        let repo = MockReminderRepository()
        let vm = ReminderRuleEditViewModel(mode: .create, medicationId: 1, repository: repo)
        vm.repeatType = .weekly
        vm.selectedDays = []
        vm.addTime(makeComponents(hour: 9, minute: 0))

        await vm.save()

        #expect(vm.saveState == .idle)
        #expect(vm.validationError != nil)
        #expect(repo.createRuleCallCount == 0)
    }

    @Test("INTERVAL rule with intervalDays = 0 fails validation")
    func saveIntervalZeroDaysFails() async {
        let repo = MockReminderRepository()
        let vm = ReminderRuleEditViewModel(mode: .create, medicationId: 1, repository: repo)
        vm.repeatType = .interval
        vm.intervalDaysText = "0"
        vm.addTime(makeComponents(hour: 10, minute: 0))

        await vm.save()

        #expect(vm.saveState == .idle)
        #expect(vm.validationError != nil)
        #expect(repo.createRuleCallCount == 0)
    }

    @Test("INTERVAL rule with non-numeric intervalDays fails validation")
    func saveIntervalNonNumericFails() async {
        let repo = MockReminderRepository()
        let vm = ReminderRuleEditViewModel(mode: .create, medicationId: 1, repository: repo)
        vm.repeatType = .interval
        vm.intervalDaysText = "abc"
        vm.addTime(makeComponents(hour: 10, minute: 0))

        await vm.save()

        #expect(vm.saveState == .idle)
        #expect(vm.validationError != nil)
    }

    @Test("Create with no times fails validation")
    func saveNoTimesFails() async {
        let repo = MockReminderRepository()
        let vm = ReminderRuleEditViewModel(mode: .create, medicationId: 1, repository: repo)
        vm.repeatType = .daily
        // no times added

        await vm.save()

        #expect(vm.saveState == .idle)
        #expect(vm.validationError != nil)
        #expect(repo.createRuleCallCount == 0)
    }

    @Test("Network error on createRule sets saveState to .failed")
    func saveCreateNetworkError() async {
        let repo = MockReminderRepository()
        repo.createRuleResult = .failure(APIError.network)

        let vm = ReminderRuleEditViewModel(mode: .create, medicationId: 1, repository: repo)
        vm.repeatType = .daily
        vm.addTime(makeComponents(hour: 8, minute: 0))

        await vm.save()

        #expect(vm.saveState == .failed(.network))
    }

    // MARK: - addTime / removeTime

    @Test("addTime appends a new TimeDraft")
    func addTimeAppends() {
        let repo = MockReminderRepository()
        let vm = ReminderRuleEditViewModel(mode: .create, medicationId: 1, repository: repo)

        vm.addTime(makeComponents(hour: 8, minute: 0))
        vm.addTime(makeComponents(hour: 12, minute: 30))

        #expect(vm.times.count == 2)
        #expect(vm.times[0].hour == 8)
        #expect(vm.times[1].minute == 30)
    }

    @Test("removeTime removes the draft at given offsets")
    func removeTimeRemoves() {
        let repo = MockReminderRepository()
        let vm = ReminderRuleEditViewModel(mode: .create, medicationId: 1, repository: repo)
        vm.addTime(makeComponents(hour: 8, minute: 0))
        vm.addTime(makeComponents(hour: 12, minute: 0))

        vm.removeTime(at: IndexSet(integer: 0))

        #expect(vm.times.count == 1)
        #expect(vm.times[0].hour == 12)
    }

    // MARK: - Edit mode

    @Test("edit mode pre-populates fields from existing rule")
    func editModePrePopulates() {
        let rule = ReminderRule(
            id: 5, repeatType: .interval, intervalDays: 3,
            daysOfWeek: [], active: true,
            times: [ReminderTime(id: 1, hour: 7, minute: 45)]
        )
        let repo = MockReminderRepository()
        let vm = ReminderRuleEditViewModel(mode: .edit(rule), medicationId: 1, repository: repo)

        #expect(vm.repeatType == .interval)
        #expect(vm.intervalDaysText == "3")
        #expect(vm.times.count == 1)
        #expect(vm.times[0].existingId == 1)
        #expect(vm.times[0].hour == 7)
    }

    @Test("edit mode save calls updateRule then syncs times")
    func editModeSave() async {
        let existingTime = ReminderTime(id: 10, hour: 8, minute: 0)
        let rule = ReminderRule(
            id: 5, repeatType: .daily, intervalDays: nil,
            daysOfWeek: [], active: true, times: [existingTime]
        )
        let repo = MockReminderRepository()
        repo.updateRuleResult = .success(rule)
        repo.addTimeResult = .success(MockReminderRepository.makeTestTime(id: 20, hour: 20, minute: 0))

        let vm = ReminderRuleEditViewModel(mode: .edit(rule), medicationId: 1, repository: repo)
        // Keep existing time and add a new one
        vm.addTime(makeComponents(hour: 20, minute: 0))

        await vm.save()

        #expect(vm.saveState == .saved)
        #expect(repo.updateRuleCallCount == 1)
        // No deletions (existing time was kept), one addition
        #expect(repo.deleteTimeCallCount == 0)
        #expect(repo.addTimeCallCount == 1)
    }

    @Test("edit mode save deletes removed existing times")
    func editModeDeletesRemovedTime() async {
        let time1 = ReminderTime(id: 10, hour: 8, minute: 0)
        let time2 = ReminderTime(id: 11, hour: 20, minute: 0)
        let rule = ReminderRule(
            id: 5, repeatType: .daily, intervalDays: nil,
            daysOfWeek: [], active: true, times: [time1, time2]
        )
        let repo = MockReminderRepository()
        repo.updateRuleResult = .success(rule)

        let vm = ReminderRuleEditViewModel(mode: .edit(rule), medicationId: 1, repository: repo)
        // Remove the second time (index 1)
        vm.removeTime(at: IndexSet(integer: 1))

        await vm.save()

        #expect(vm.saveState == .saved)
        #expect(repo.deleteTimeCallCount == 1)
        #expect(repo.lastDeletedTimeId == 11)
        #expect(repo.addTimeCallCount == 0)
    }

    // MARK: - delete()

    @Test("delete() success calls deleteRule and sets saveState to .saved")
    func deleteSuccess() async {
        let rule = MockReminderRepository.makeTestRule(id: 7)
        let repo = MockReminderRepository()
        repo.deleteRuleResult = .success(())

        let vm = ReminderRuleEditViewModel(mode: .edit(rule), medicationId: 1, repository: repo)
        await vm.delete()

        #expect(repo.deleteRuleCallCount == 1)
        #expect(repo.lastDeletedRuleId == 7)
        #expect(vm.saveState == .saved)
        #expect(vm.deleteError == nil)
    }

    @Test("delete() notFound sets deleteError")
    func deleteNotFound() async {
        let rule = MockReminderRepository.makeTestRule(id: 7)
        let repo = MockReminderRepository()
        repo.deleteRuleResult = .failure(APIError.notFound)

        let vm = ReminderRuleEditViewModel(mode: .edit(rule), medicationId: 1, repository: repo)
        await vm.delete()

        #expect(vm.deleteError == .notFound)
        #expect(vm.saveState == .idle)
    }

    // MARK: - Helpers

    private func makeComponents(hour: Int, minute: Int) -> DateComponents {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return comps
    }
}
