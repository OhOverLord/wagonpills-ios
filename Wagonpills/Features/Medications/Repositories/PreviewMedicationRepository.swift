#if DEBUG
import Foundation

struct PreviewMedicationRepository: MedicationRepository {
    var medications: [Medication]
    var error: APIError?

    init(medications: [Medication] = [], error: APIError? = nil) {
        self.medications = medications
        self.error = error
    }

    func fetchAll(activeOnly: Bool?) async throws -> [Medication] {
        if let error { throw error }
        return medications
    }

    func fetchById(_ id: Int64) async throws -> Medication {
        if let error { throw error }
        guard let found = medications.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return found
    }
}
#endif
