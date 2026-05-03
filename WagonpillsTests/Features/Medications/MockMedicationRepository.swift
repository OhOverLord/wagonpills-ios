import Foundation
@testable import Wagonpills

final class MockMedicationRepository: MedicationRepository, @unchecked Sendable {
    var fetchAllResult: Result<[Medication], Error> = .success([])
    var fetchByIdResult: Result<Medication, Error> = .failure(APIError.notFound)
    var createResult: Result<Medication, Error> = .failure(APIError.unexpected("not configured"))
    var updateResult: Result<Medication, Error> = .failure(APIError.unexpected("not configured"))
    var deleteResult: Result<Void, Error> = .success(())

    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var lastDeletedId: Int64?

    func fetchAll(activeOnly: Bool?) async throws -> [Medication] {
        try fetchAllResult.get()
    }

    func fetchById(_ id: Int64) async throws -> Medication {
        try fetchByIdResult.get()
    }

    func create(_ request: MedicationCreateRequest) async throws -> Medication {
        createCallCount += 1
        return try createResult.get()
    }

    func update(id: Int64, _ request: MedicationUpdateRequest) async throws -> Medication {
        updateCallCount += 1
        return try updateResult.get()
    }

    func delete(id: Int64) async throws {
        deleteCallCount += 1
        lastDeletedId = id
        try deleteResult.get()
    }

    func addStock(medicationId: Int64, quantity: Double, note: String?) async throws {}

    func adjustStock(medicationId: Int64, quantity: Double, note: String?) async throws {}

    var fetchStockSummaryResult: Result<StockSummary, Error> = .success(
        StockSummary(
            medicationId: 1, medicationName: "Aspirin", currentStock: 10,
            unit: .tablet, lowStockThreshold: 5, isLowStock: false
        )
    )
    var fetchStockHistoryResult: Result<[StockMovement], Error> = .success([])
    private(set) var fetchStockSummaryCallCount = 0
    private(set) var fetchStockHistoryCallCount = 0

    func fetchStockSummary(medicationId: Int64) async throws -> StockSummary {
        fetchStockSummaryCallCount += 1
        return try fetchStockSummaryResult.get()
    }

    func fetchStockHistory(medicationId: Int64) async throws -> [StockMovement] {
        fetchStockHistoryCallCount += 1
        return try fetchStockHistoryResult.get()
    }

    static func makeTestMedication(id: Int64 = 1, name: String = "Aspirin") -> Medication {
        Medication(
            id: id,
            name: name,
            dosageText: "500 mg",
            instructions: nil,
            startDate: Date(),
            endDate: nil,
            isActive: true,
            stockUnit: .tablet,
            doseQuantity: 1,
            currentStock: 10,
            lowStockThreshold: 5,
            catalogItemId: nil,
            regionCode: nil,
            createdAt: Date(timeIntervalSinceNow: -86400),
            updatedAt: Date()
        )
    }
}
