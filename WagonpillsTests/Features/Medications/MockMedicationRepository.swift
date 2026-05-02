import Foundation
@testable import Wagonpills

final class MockMedicationRepository: MedicationRepository, @unchecked Sendable {
    var fetchAllResult: Result<[Medication], Error> = .success([])
    var fetchByIdResult: Result<Medication, Error> = .failure(APIError.notFound)

    func fetchAll(activeOnly: Bool?) async throws -> [Medication] {
        try fetchAllResult.get()
    }

    func fetchById(_ id: Int64) async throws -> Medication {
        try fetchByIdResult.get()
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
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
