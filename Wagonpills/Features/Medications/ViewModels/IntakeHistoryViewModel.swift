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
    var statusFilter: IntakeStatus?
    var fromDate: Date
    var toDate: Date

    let medicationId: Int64
    private let repository: any IntakeLogRepository

    init(medicationId: Int64, repository: any IntakeLogRepository) {
        self.medicationId = medicationId
        self.repository = repository
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        // toDate is the last *calendar day* to include. The actual upper bound sent
        // to the API is start-of-next-day so future-scheduled doses on toDate are included.
        self.toDate = startOfToday
        self.fromDate = calendar.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday
    }

    func load() async {
        state = .loading
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let clampedTo = min(calendar.startOfDay(for: toDate), today)
        let clampedFrom = min(calendar.startOfDay(for: fromDate), clampedTo)
        let exclusiveUpperBound = calendar.date(byAdding: .day, value: 1, to: clampedTo)
        do {
            let logs = try await repository.fetchLogs(
                medicationId: medicationId,
                from: clampedFrom,
                to: exclusiveUpperBound,
                status: statusFilter
            )
            state = logs.isEmpty ? .empty : .loaded(logs)
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
