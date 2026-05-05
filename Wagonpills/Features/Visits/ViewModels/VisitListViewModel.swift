import Foundation
import Observation

@MainActor
@Observable
final class VisitListViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([Visit])
        case empty
        case failed(APIError)
    }

    private(set) var state: State = .idle
    private(set) var isDeleting = false

    let repository: any VisitRepository

    init(repository: any VisitRepository) {
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

    func delete(_ visit: Visit) async {
        isDeleting = true
        do {
            try await repository.delete(id: visit.id)
            if case .loaded(var visits) = state {
                visits.removeAll { $0.id == visit.id }
                state = visits.isEmpty ? .empty : .loaded(visits)
            }
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
        isDeleting = false
    }

    private func fetch() async {
        do {
            let visits = try await repository.fetchAll()
            let sorted = visits.sorted { $0.visitAt > $1.visitAt }
            state = sorted.isEmpty ? .empty : .loaded(sorted)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }
}
