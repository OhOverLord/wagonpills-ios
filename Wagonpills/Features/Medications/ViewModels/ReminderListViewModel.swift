import Foundation
import Observation

@MainActor
@Observable
final class ReminderListViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([ReminderRule])
        case empty
        case failed(APIError)
    }

    private(set) var state: State = .idle
    let medicationId: Int64
    let repository: any ReminderRepository

    init(medicationId: Int64, repository: any ReminderRepository) {
        self.medicationId = medicationId
        self.repository = repository
    }

    func load() async {
        if state == .idle { state = .loading }
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        do {
            let rules = try await repository.fetchRules(medicationId: medicationId)
            state = rules.isEmpty ? .empty : .loaded(rules)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }

    func delete(rule: ReminderRule) async {
        do {
            try await repository.deleteRule(medicationId: medicationId, ruleId: rule.id)
            await fetch()
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }
}
