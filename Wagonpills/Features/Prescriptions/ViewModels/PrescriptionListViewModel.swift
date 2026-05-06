import Foundation
import Observation

@MainActor
@Observable
final class PrescriptionListViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([Prescription])
        case empty
        case failed(APIError)
    }

    private(set) var state: State = .idle
    private(set) var isDeleting = false
    private(set) var availableVisits: [Visit] = []

    let repository: any PrescriptionRepository
    let visitRepository: any VisitRepository

    init(repository: any PrescriptionRepository, visitRepository: any VisitRepository) {
        self.repository = repository
        self.visitRepository = visitRepository
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

    func delete(_ prescription: Prescription) async {
        isDeleting = true
        do {
            try await repository.delete(id: prescription.id)
            if case .loaded(var prescriptions) = state {
                prescriptions.removeAll { $0.id == prescription.id }
                state = prescriptions.isEmpty ? .empty : .loaded(prescriptions)
            }
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
        isDeleting = false
    }

    private func fetch() async {
        async let prescriptionsFetch = repository.fetchAll()
        async let visitsFetch = visitRepository.fetchAll()
        do {
            let prescriptions = try await prescriptionsFetch
            availableVisits = (try? await visitsFetch) ?? []
            let sorted = prescriptions.sorted {
                switch ($0.issuedAt, $1.issuedAt) {
                case (let lhs?, let rhs?): return lhs > rhs
                case (nil, _): return false
                case (_, nil): return true
                }
            }
            state = sorted.isEmpty ? .empty : .loaded(sorted)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }
}
