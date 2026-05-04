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

    func fetchStockSummary(medicationId: Int64) async throws -> StockSummary {
        if let error { throw error }
        guard let med = medications.first(where: { $0.id == medicationId }) else {
            throw APIError.notFound
        }
        return StockSummary(
            medicationId: med.id,
            medicationName: med.name,
            currentStock: med.currentStock ?? 0,
            unit: med.stockUnit,
            lowStockThreshold: med.lowStockThreshold,
            isLowStock: med.currentStock.map { stock in
                med.lowStockThreshold.map { stock < $0 } ?? false
            } ?? false
        )
    }

    func fetchStockHistory(medicationId: Int64) async throws -> [StockMovement] {
        if let error { throw error }
        let now = Date()
        return [
            StockMovement(
                id: 1, medicationId: medicationId, movementType: .add,
                quantity: 30, unit: .tablet, relatedIntakeLogId: nil,
                note: "Bought at pharmacy", createdAt: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            ),
            StockMovement(
                id: 2, medicationId: medicationId, movementType: .consume,
                quantity: 2, unit: .tablet, relatedIntakeLogId: 10,
                note: nil, createdAt: Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now
            ),
            StockMovement(
                id: 3, medicationId: medicationId, movementType: .adjust,
                quantity: -1, unit: .tablet, relatedIntakeLogId: nil,
                note: "Correction", createdAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
            )
        ]
    }

    func fetchChanges(medicationId: Int64) async throws -> [MedicationChange] {
        if let error { throw error }
        let now = Date()
        return [
            MedicationChange(
                id: 1, medicationId: medicationId, medicationName: "Metformin",
                doctorVisitId: nil, changeType: .start, oldValue: nil, newValue: nil,
                reason: "New prescription", changedAt: Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now
            ),
            MedicationChange(
                id: 2, medicationId: medicationId, medicationName: "Metformin",
                doctorVisitId: 5, changeType: .dosageChange, oldValue: "500mg", newValue: "1000mg",
                reason: "Increased for better control", changedAt: Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
            )
        ]
    }

    func createChange(medicationId: Int64, _ request: MedicationChangeCreateRequest) async throws -> MedicationChange {
        if let error { throw error }
        return MedicationChange(
            id: Int64.random(in: 100...999),
            medicationId: medicationId,
            medicationName: medications.first(where: { $0.id == medicationId })?.name ?? "Medication",
            doctorVisitId: request.doctorVisitId,
            changeType: request.changeType,
            oldValue: request.oldValue.flatMap { $0.isEmpty ? nil : $0 },
            newValue: request.newValue.flatMap { $0.isEmpty ? nil : $0 },
            reason: request.reason.flatMap { $0.isEmpty ? nil : $0 },
            changedAt: Date()
        )
    }
}
#endif
