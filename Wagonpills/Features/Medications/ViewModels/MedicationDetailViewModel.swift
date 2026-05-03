import Foundation
import Observation

@MainActor
@Observable
final class MedicationDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(Medication)
        case failed(APIError)
    }

    private(set) var state: State = .loading
    let medicationId: Int64

    let repository: any MedicationRepository
    let reminderRepository: any ReminderRepository
    let intakeLogRepository: any IntakeLogRepository
    let catalogRepository: any CatalogRepository

    init(
        medicationId: Int64,
        repository: any MedicationRepository,
        reminderRepository: any ReminderRepository,
        intakeLogRepository: any IntakeLogRepository,
        catalogRepository: any CatalogRepository
    ) {
        self.medicationId = medicationId
        self.repository = repository
        self.reminderRepository = reminderRepository
        self.intakeLogRepository = intakeLogRepository
        self.catalogRepository = catalogRepository
    }

    func load() async {
        do {
            let medication = try await repository.fetchById(medicationId)
            state = .loaded(medication)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }
}
