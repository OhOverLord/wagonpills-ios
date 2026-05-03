import Foundation
import Testing
@testable import Wagonpills

@Suite("IntakeHistoryViewModel")
@MainActor
struct IntakeHistoryViewModelTests {
    private static func makeLog(
        id: Int64,
        status: IntakeStatus,
        daysAgo: Int = 0,
        hourOffset: Int = 8
    ) -> IntakeLog {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) - daysAgo
        comps.hour = hourOffset
        comps.minute = 0
        let scheduled = Calendar.current.date(from: comps) ?? Date()
        return IntakeLog(
            id: id,
            medicationId: 1,
            scheduledTime: scheduled,
            status: status,
            note: nil,
            takenAt: status == .taken ? scheduled : nil
        )
    }

    @Test("load() with .taken filter calls repository with .taken status")
    func loadWithTakenFilterCallsRepoWithTakenStatus() async throws {
        let repo = MockIntakeLogRepository()
        repo.fetchLogsResult = .success([Self.makeLog(id: 1, status: .taken)])
        let vm = IntakeHistoryViewModel(medicationId: 7, repository: repo)
        vm.statusFilter = .taken

        await vm.load()

        #expect(repo.fetchLogsCallCount == 1)
        #expect(repo.lastFetchStatus == .taken)
        #expect(repo.lastFetchMedicationId == 7)
    }

    @Test("changing statusFilter triggers new load with updated filter")
    func statusFilterChangeLoadsWithNewFilter() async throws {
        let repo = MockIntakeLogRepository()
        repo.fetchLogsResult = .success([Self.makeLog(id: 1, status: .missed)])
        let vm = IntakeHistoryViewModel(medicationId: 1, repository: repo)

        await vm.load()
        #expect(repo.fetchLogsCallCount == 1)
        #expect(repo.lastFetchStatus == nil)

        vm.statusFilter = .missed
        await vm.load()
        #expect(repo.fetchLogsCallCount == 2)
        #expect(repo.lastFetchStatus == .missed)
    }

    @Test("empty result transitions to .empty state")
    func emptyResultTransitionsToEmptyState() async {
        let repo = MockIntakeLogRepository()
        repo.fetchLogsResult = .success([])
        let vm = IntakeHistoryViewModel(medicationId: 1, repository: repo)

        await vm.load()

        #expect(vm.state == .empty)
    }

    @Test("non-empty result transitions to .loaded state")
    func nonEmptyResultTransitionsToLoadedState() async {
        let repo = MockIntakeLogRepository()
        let logs = [Self.makeLog(id: 1, status: .taken), Self.makeLog(id: 2, status: .missed)]
        repo.fetchLogsResult = .success(logs)
        let vm = IntakeHistoryViewModel(medicationId: 1, repository: repo)

        await vm.load()

        if case .loaded(let loaded) = vm.state {
            #expect(loaded.count == 2)
        } else {
            Issue.record("Expected .loaded, got \(vm.state)")
        }
    }

    @Test("network error transitions to .failed state")
    func networkErrorTransitionsToFailedState() async {
        let repo = MockIntakeLogRepository()
        repo.fetchLogsResult = .failure(APIError.server(status: 503))
        let vm = IntakeHistoryViewModel(medicationId: 1, repository: repo)

        await vm.load()

        if case .failed(let error) = vm.state {
            #expect(error == .server(status: 503))
        } else {
            Issue.record("Expected .failed, got \(vm.state)")
        }
    }

    @Test("adherenceSummary counts only .taken logs")
    func adherenceSummaryCountsTakenLogs() async {
        let repo = MockIntakeLogRepository()
        repo.fetchLogsResult = .success([
            Self.makeLog(id: 1, status: .taken),
            Self.makeLog(id: 2, status: .taken),
            Self.makeLog(id: 3, status: .missed),
            Self.makeLog(id: 4, status: .skipped)
        ])
        let vm = IntakeHistoryViewModel(medicationId: 1, repository: repo)
        await vm.load()

        let summary = vm.adherenceSummary
        #expect(summary?.taken == 2)
        #expect(summary?.total == 4)
    }

    @Test("logsByDay groups logs by calendar day newest first")
    func logsByDayGroupsNewestFirst() async {
        let repo = MockIntakeLogRepository()
        repo.fetchLogsResult = .success([
            Self.makeLog(id: 1, status: .taken, daysAgo: 0),
            Self.makeLog(id: 2, status: .taken, daysAgo: 1),
            Self.makeLog(id: 3, status: .missed, daysAgo: 1)
        ])
        let vm = IntakeHistoryViewModel(medicationId: 1, repository: repo)
        await vm.load()

        let groups = vm.logsByDay
        #expect(groups.count == 2)
        #expect(groups[0].logs.count == 1)
        #expect(groups[1].logs.count == 2)
        #expect(groups[0].day > groups[1].day)
    }
}
