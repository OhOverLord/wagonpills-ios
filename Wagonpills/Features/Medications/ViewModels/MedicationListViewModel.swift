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
    private(set) var deleteError: APIError?

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

    func delete(_ medication: Medication) async {
        deleteError = nil
        do {
            try await repository.delete(id: medication.id)
            if case .loaded(var medications) = state {
                medications.removeAll { $0.id == medication.id }
                state = medications.isEmpty ? .empty : .loaded(medications)
            }
        } catch let error as APIError {
            deleteError = error
        } catch {
            deleteError = APIError.from(error)
        }
    }

    func clearDeleteError() {
        deleteError = nil
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
