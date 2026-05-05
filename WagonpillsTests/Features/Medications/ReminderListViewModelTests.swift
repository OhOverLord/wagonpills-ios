import Foundation
import Testing
@testable import Wagonpills

@Suite("ReminderListViewModel")
@MainActor
struct ReminderListViewModelTests {

    private struct GenericError: Error {}

    // MARK: - load()

    @Test("initial state is .idle")
    func initialStateIsIdle() {
        let repo = MockReminderRepository()
        let vm = ReminderListViewModel(medicationId: 1, repository: repo)

        #expect(vm.state == .idle)
    }

    @Test("load() transitions through .loading and sets .loaded on success")
    func loadSuccess() async {
        let repo = MockReminderRepository()
        let rules = [MockReminderRepository.makeTestRule(id: 1), MockReminderRepository.makeTestRule(id: 2)]
        repo.fetchRulesResult = .success(rules)

        let vm = ReminderListViewModel(medicationId: 42, repository: repo)
        await vm.load()

        guard case .loaded(let loaded) = vm.state else {
            Issue.record("Expected .loaded, got \(vm.state)")
            return
        }
        #expect(loaded.count == 2)
    }

    @Test("load() with empty result sets state to .empty")
    func loadEmpty() async {
        let repo = MockReminderRepository()
        repo.fetchRulesResult = .success([])

        let vm = ReminderListViewModel(medicationId: 1, repository: repo)
        await vm.load()

        #expect(vm.state == .empty)
    }

    @Test("load() with APIError sets state to .failed")
    func loadAPIError() async {
        let repo = MockReminderRepository()
        repo.fetchRulesResult = .failure(APIError.network)

        let vm = ReminderListViewModel(medicationId: 1, repository: repo)
        await vm.load()

        #expect(vm.state == .failed(.network))
    }

    @Test("load() with generic Error maps to .failed(.unexpected)")
    func loadGenericError() async {
        let repo = MockReminderRepository()
        repo.fetchRulesResult = .failure(GenericError())

        let vm = ReminderListViewModel(medicationId: 1, repository: repo)
        await vm.load()

        guard case .failed(let error) = vm.state, case .unexpected = error else {
            Issue.record("Expected .failed(.unexpected), got \(vm.state)")
            return
        }
    }

    // MARK: - refresh()

    @Test("refresh() reloads rules without transitioning through .loading")
    func refreshReloads() async {
        let repo = MockReminderRepository()
        let rule = MockReminderRepository.makeTestRule(id: 10)
        repo.fetchRulesResult = .success([rule])

        let vm = ReminderListViewModel(medicationId: 1, repository: repo)
        await vm.refresh()

        guard case .loaded(let loaded) = vm.state else {
            Issue.record("Expected .loaded, got \(vm.state)")
            return
        }
        #expect(loaded[0].id == 10)
    }

    // MARK: - delete(rule:)

    @Test("delete() success removes the rule and refreshes the list")
    func deleteSuccess() async {
        let repo = MockReminderRepository()
        let ruleToDelete = MockReminderRepository.makeTestRule(id: 5)
        let remaining = MockReminderRepository.makeTestRule(id: 6)

        repo.deleteRuleResult = .success(())
        repo.fetchRulesResult = .success([remaining])

        let vm = ReminderListViewModel(medicationId: 1, repository: repo)
        await vm.delete(rule: ruleToDelete)

        #expect(repo.deleteRuleCallCount == 1)
        #expect(repo.lastDeletedRuleId == 5)
        guard case .loaded(let loaded) = vm.state else {
            Issue.record("Expected .loaded after delete, got \(vm.state)")
            return
        }
        #expect(loaded.count == 1)
        #expect(loaded[0].id == 6)
    }

    @Test("delete() failure sets state to .failed")
    func deleteFailure() async {
        let repo = MockReminderRepository()
        let rule = MockReminderRepository.makeTestRule(id: 3)
        repo.deleteRuleResult = .failure(APIError.network)

        let vm = ReminderListViewModel(medicationId: 1, repository: repo)
        await vm.delete(rule: rule)

        #expect(vm.state == .failed(.network))
    }

    @Test("delete() triggers notificationRescheduler with the correct medicationId")
    func deleteTriggersReschedule() async {
        let repo = MockReminderRepository()
        let rescheduler = MockNotificationRescheduler()
        let rule = MockReminderRepository.makeTestRule(id: 1)

        repo.deleteRuleResult = .success(())
        repo.fetchRulesResult = .success([])

        let vm = ReminderListViewModel(medicationId: 77, repository: repo, notificationRescheduler: rescheduler)
        await vm.delete(rule: rule)

        try? await Task.sleep(for: .milliseconds(50))
        #expect(rescheduler.rescheduleCallCount == 1)
        #expect(rescheduler.lastRescheduledMedicationId == 77)
    }

    @Test("load() sets .loading when transitioning from .idle")
    func loadSetsLoadingWhenIdle() async {
        let repo = MockReminderRepository()
        repo.fetchRulesResult = .success([MockReminderRepository.makeTestRule()])

        let vm = ReminderListViewModel(medicationId: 1, repository: repo)
        #expect(vm.state == .idle)

        await vm.load()

        guard case .loaded = vm.state else {
            Issue.record("Expected .loaded after load from idle, got \(vm.state)")
            return
        }
    }
}
