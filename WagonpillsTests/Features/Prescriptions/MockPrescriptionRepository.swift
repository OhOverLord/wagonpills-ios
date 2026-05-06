import Foundation
@testable import Wagonpills

final class MockPrescriptionRepository: PrescriptionRepository, @unchecked Sendable {
    var fetchAllResult: Result<[Prescription], Error> = .success([])
    var fetchByIdResult: Result<Prescription, Error> = .failure(APIError.notFound)
    var createResult: Result<Prescription, Error> = .failure(APIError.unexpected("not configured"))
    var updateResult: Result<Prescription, Error> = .failure(APIError.unexpected("not configured"))
    var deleteResult: Result<Void, Error> = .success(())
    var fetchItemsResult: Result<[PrescriptionItem], Error> = .success([])
    var createItemResult: Result<PrescriptionItem, Error> = .failure(APIError.unexpected("not configured"))
    var updateItemResult: Result<PrescriptionItem, Error> = .failure(APIError.unexpected("not configured"))
    var deleteItemResult: Result<Void, Error> = .success(())

    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var lastDeletedId: Int64?
    private(set) var createItemCallCount = 0
    private(set) var updateItemCallCount = 0
    private(set) var deleteItemCallCount = 0

    func fetchAll() async throws -> [Prescription] {
        try fetchAllResult.get()
    }

    func fetchById(_ id: Int64) async throws -> Prescription {
        try fetchByIdResult.get()
    }

    func create(_ request: PrescriptionCreateRequest) async throws -> Prescription {
        createCallCount += 1
        return try createResult.get()
    }

    func update(id: Int64, _ request: PrescriptionUpdateRequest) async throws -> Prescription {
        updateCallCount += 1
        return try updateResult.get()
    }

    func delete(id: Int64) async throws {
        deleteCallCount += 1
        lastDeletedId = id
        try deleteResult.get()
    }

    func fetchItems(prescriptionId: Int64) async throws -> [PrescriptionItem] {
        try fetchItemsResult.get()
    }

    func createItem(
        prescriptionId: Int64,
        _ request: PrescriptionItemCreateRequest
    ) async throws -> PrescriptionItem {
        createItemCallCount += 1
        return try createItemResult.get()
    }

    func updateItem(
        prescriptionId: Int64,
        itemId: Int64,
        _ request: PrescriptionItemUpdateRequest
    ) async throws -> PrescriptionItem {
        updateItemCallCount += 1
        return try updateItemResult.get()
    }

    func deleteItem(prescriptionId: Int64, itemId: Int64) async throws {
        deleteItemCallCount += 1
        try deleteItemResult.get()
    }

    static func makeTestPrescription(id: Int64 = 1, note: String? = "Test note") -> Prescription {
        Prescription(
            id: id,
            doctorVisitId: nil,
            issuedAt: Date(),
            note: note,
            createdAt: Date(timeIntervalSinceNow: -86400),
            items: []
        )
    }

    static func makeTestItem(id: Int64 = 1, prescriptionId: Int64 = 1) -> PrescriptionItem {
        PrescriptionItem(
            id: id,
            prescriptionId: prescriptionId,
            medicationName: "Amoxicillin",
            dosageText: "500 mg",
            instructions: nil,
            durationDays: 7
        )
    }
}
