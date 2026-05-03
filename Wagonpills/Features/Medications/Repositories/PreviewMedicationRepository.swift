#if DEBUG
import Foundation

struct PreviewMedicationRepository: MedicationRepository {
    var medications: [Medication]
    var error: APIError?
    var createResult: Result<Medication, APIError>?
    var updateResult: Result<Medication, APIError>?
    var deleteError: APIError?

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

    func create(_ request: MedicationCreateRequest) async throws -> Medication {
        if let result = createResult { return try result.get() }
        let med = Medication(
            id: Int64.random(in: 100...999),
            name: request.name,
            dosageText: request.dosageText,
            instructions: request.instructions,
            startDate: request.startDate,
            endDate: request.endDate,
            isActive: true,
            stockUnit: request.stockUnit,
            doseQuantity: request.doseQuantity,
            currentStock: request.currentStock,
            lowStockThreshold: request.lowStockThreshold,
            catalogItemId: request.catalogItemId,
            regionCode: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        return med
    }

    func update(id: Int64, _ request: MedicationUpdateRequest) async throws -> Medication {
        if let result = updateResult { return try result.get() }
        guard let existing = medications.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return Medication(
            id: existing.id,
            name: request.name,
            dosageText: request.dosageText,
            instructions: request.instructions,
            startDate: request.startDate,
            endDate: request.endDate,
            isActive: request.isActive,
            stockUnit: request.stockUnit,
            doseQuantity: request.doseQuantity,
            currentStock: existing.currentStock,
            lowStockThreshold: request.lowStockThreshold,
            catalogItemId: existing.catalogItemId,
            regionCode: existing.regionCode,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
    }

    func delete(id: Int64) async throws {
        if let error = deleteError { throw error }
    }

    func addStock(medicationId: Int64, quantity: Double, note: String?) async throws {}

    func adjustStock(medicationId: Int64, quantity: Double, note: String?) async throws {}
}
#endif
