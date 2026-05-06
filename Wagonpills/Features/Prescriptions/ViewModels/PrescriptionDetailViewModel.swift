import Foundation
import Observation

@MainActor
@Observable
final class PrescriptionDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(Prescription)
        case failed(APIError)
    }

    private(set) var state: State = .loading
    private(set) var isDeletingItem = false
    private(set) var availableVisits: [Visit] = []

    var linkedVisit: Visit? {
        guard case .loaded(let prescription) = state,
              let visitId = prescription.doctorVisitId else { return nil }
        return availableVisits.first { $0.id == visitId }
    }

    let prescriptionId: Int64
    let repository: any PrescriptionRepository
    private let visitRepository: any VisitRepository

    init(prescriptionId: Int64, repository: any PrescriptionRepository, visitRepository: any VisitRepository) {
        self.prescriptionId = prescriptionId
        self.repository = repository
        self.visitRepository = visitRepository
    }

    func load() async {
        async let prescriptionFetch = repository.fetchById(prescriptionId)
        async let visitsFetch = visitRepository.fetchAll()
        do {
            let prescription = try await prescriptionFetch
            availableVisits = (try? await visitsFetch) ?? availableVisits
            state = .loaded(prescription)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }

    func deleteItem(_ item: PrescriptionItem) async {
        guard case .loaded(let prescription) = state else { return }
        isDeletingItem = true
        do {
            try await repository.deleteItem(prescriptionId: prescription.id, itemId: item.id)
            await load()
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
        isDeletingItem = false
    }
}
