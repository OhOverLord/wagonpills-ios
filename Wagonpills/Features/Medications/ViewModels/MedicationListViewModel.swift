import Foundation
import Observation

@MainActor
@Observable
final class MedicationListViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([Medication])
        case empty
        case failed(APIError)
    }

    private(set) var state: State = .idle
    var showActiveOnly: Bool = false

    let repository: any MedicationRepository

    init(repository: any MedicationRepository) {
        self.repository = repository
    }

    func load() async {
        if state == .idle {
            state = .loading
        }
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        do {
            let medications = try await repository.fetchAll(activeOnly: showActiveOnly ? true : nil)
            state = medications.isEmpty ? .empty : .loaded(medications)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }
}
