import Foundation
import Observation

@MainActor
@Observable
final class IntakeHistoryViewModel {
    enum State: Equatable {
        case loading
        case loaded([IntakeLog])
        case empty
        case failed(APIError)
    }

    private(set) var state: State = .loading
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    var statusFilter: IntakeStatus?
    var fromDate: Date
    var toDate: Date

    let medicationId: Int64
    private let repository: any IntakeLogRepository
    private var currentPage = 0

    init(medicationId: Int64, repository: any IntakeLogRepository) {
        self.medicationId = medicationId
        self.repository = repository
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        self.toDate = startOfToday
        self.fromDate = calendar.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday
    }

    func load() async {
        state = .loading
        currentPage = 0
        hasMore = false
        do {
            let result = try await fetchPage(0)
            currentPage = 0
            hasMore = result.hasMore
            state = result.logs.isEmpty ? .empty : .loaded(result.logs)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, case .loaded(let existing) = state else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let nextPage = currentPage + 1
            let result = try await fetchPage(nextPage)
            currentPage = nextPage
            hasMore = result.hasMore
            state = .loaded(existing + result.logs)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }

    var adherenceSummary: (taken: Int, total: Int)? {
        guard case .loaded(let logs) = state else { return nil }
        let taken = logs.filter { $0.status == .taken }.count
        return (taken: taken, total: logs.count)
    }

    var logsByDay: [(day: Date, logs: [IntakeLog])] {
        guard case .loaded(let logs) = state else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.scheduledTime) }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, logs: $0.value.sorted { $0.scheduledTime > $1.scheduledTime }) }
    }
}

// MARK: - Private

private extension IntakeHistoryViewModel {
    func fetchPage(_ page: Int) async throws -> IntakeLogPage {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let clampedTo = min(calendar.startOfDay(for: toDate), today)
        let clampedFrom = min(calendar.startOfDay(for: fromDate), clampedTo)
        let exclusiveUpperBound = calendar.date(byAdding: .day, value: 1, to: clampedTo)
        return try await repository.fetchLogs(
            medicationId: medicationId,
            from: clampedFrom,
            to: exclusiveUpperBound,
            status: statusFilter,
            page: page
        )
    }
}
