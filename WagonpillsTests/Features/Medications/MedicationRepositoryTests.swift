import Foundation
import OpenAPIRuntime
import Testing
@testable import Wagonpills

// MARK: - MockMedicationClient

final class MockMedicationClient: MedicationClient, @unchecked Sendable {
    var getAllResult: Result<Operations.GetAll3.Output, Error> = .success(
        .ok(.init(body: .any(HTTPBody(Data("[]".utf8)))))
    )
    var getByIdResult: Result<Operations.GetById5.Output, Error> = .success(
        .notFound(.init(body: .any(HTTPBody(Data("{}".utf8)))))
    )
    var createResult: Result<Operations.Create4.Output, Error> = .failure(
        APIError.unexpected("not configured")
    )
    var updateResult: Result<Operations.Update6.Output, Error> = .failure(
        APIError.unexpected("not configured")
    )
    var deleteResult: Result<Operations.Delete6.Output, Error> = .success(
        .noContent(.init())
    )

    private(set) var getAllCallCount = 0
    private(set) var getByIdCallCount = 0
    private(set) var createCallCount = 0
    private(set) var deleteCallCount = 0

    func getMedications(activeOnly: Bool?) async throws -> Operations.GetAll3.Output {
        getAllCallCount += 1
        return try getAllResult.get()
    }

    func getMedication(id: Int64) async throws -> Operations.GetById5.Output {
        getByIdCallCount += 1
        return try getByIdResult.get()
    }

    func createMedication(_ body: Components.Schemas.CreateMedicationRequest) async throws -> Operations.Create4.Output {
        createCallCount += 1
        return try createResult.get()
    }

    func updateMedication(id: Int64, _ body: Components.Schemas.UpdateMedicationRequest) async throws -> Operations.Update6.Output {
        return try updateResult.get()
    }

    func deleteMedication(id: Int64) async throws -> Operations.Delete6.Output {
        deleteCallCount += 1
        return try deleteResult.get()
    }

    func addStock(medicationId: Int64, _ body: Components.Schemas.AddStockRequest) async throws -> Operations.AddStock.Output {
        .created(.init(body: .any(HTTPBody(Data("{}".utf8)))))
    }

    func adjustStock(medicationId: Int64, _ body: Components.Schemas.AdjustStockRequest) async throws -> Operations.AdjustStock.Output {
        .created(.init(body: .any(HTTPBody(Data("{}".utf8)))))
    }
}

// MARK: - Helpers

private extension MedicationRepositoryTests {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func makeDTO(id: Int64 = 1, name: String = "Aspirin") -> Components.Schemas.MedicationResponse {
        Components.Schemas.MedicationResponse(
            id: id,
            name: name,
            startDate: "2026-01-01",
            active: true,
            stockUnit: .tablet,
            createdAt: iso8601.date(from: "2026-01-01T10:00:00Z"),
            updatedAt: iso8601.date(from: "2026-01-01T10:00:00Z")
        )
    }

    static func makeOkListOutput(dtos: [Components.Schemas.MedicationResponse]) throws -> Operations.GetAll3.Output {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dtos)
        return .ok(.init(body: .any(HTTPBody(data, length: .known(Int64(data.count)), iterationBehavior: .multiple))))
    }

    static func makeOkSingleOutput(dto: Components.Schemas.MedicationResponse) throws -> Operations.GetById5.Output {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        return .ok(.init(body: .any(HTTPBody(data, length: .known(Int64(data.count)), iterationBehavior: .multiple))))
    }

    static func makeCreatedOutput(dto: Components.Schemas.MedicationResponse) throws -> Operations.Create4.Output {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        return .created(.init(body: .any(HTTPBody(data, length: .known(Int64(data.count)), iterationBehavior: .multiple))))
    }
}

// MARK: - Tests

@Suite("MedicationRepository")
@MainActor
struct MedicationRepositoryTests {
    @Test("fetchAll with empty cache calls network, populates cache, returns models")
    func fetchAllEmptyCache() async throws {
        let client = MockMedicationClient()
        let cache = MockCacheStore()
        let dto = Self.makeDTO()
        client.getAllResult = .success(try Self.makeOkListOutput(dtos: [dto]))

        let repo = LiveMedicationRepository(apiClient: client, cache: cache)
        let medications = try await repo.fetchAll(activeOnly: nil)

        #expect(client.getAllCallCount == 1)
        #expect(medications.count == 1)
        #expect(medications[0].name == "Aspirin")
        #expect(cache.hasValue(forKey: "medications.list"))
    }

    @Test("fetchAll second call with warm cache still hits network (cache-first means we always refresh)")
    func fetchAllWarmCacheNetworkSucceeds() async throws {
        let client = MockMedicationClient()
        let cache = MockCacheStore()
        let dto = Self.makeDTO()
        client.getAllResult = .success(try Self.makeOkListOutput(dtos: [dto]))

        let repo = LiveMedicationRepository(apiClient: client, cache: cache)
        _ = try await repo.fetchAll(activeOnly: nil)
        _ = try await repo.fetchAll(activeOnly: nil)

        #expect(client.getAllCallCount == 2)
    }

    @Test("fetchAll network failure with warm cache returns stale data without throwing")
    func fetchAllNetworkFailureWarmCache() async throws {
        let client = MockMedicationClient()
        let cache = MockCacheStore()
        let stale = [Medication(
            id: 99, name: "Cached", dosageText: nil, instructions: nil,
            startDate: Date(), endDate: nil, isActive: true, stockUnit: .tablet,
            doseQuantity: nil, currentStock: nil, lowStockThreshold: nil,
            catalogItemId: nil, regionCode: nil, createdAt: Date(), updatedAt: Date()
        )]
        cache.save(stale, forKey: "medications.list")
        client.getAllResult = .failure(URLError(.notConnectedToInternet))

        let repo = LiveMedicationRepository(apiClient: client, cache: cache)
        let medications = try await repo.fetchAll(activeOnly: nil)

        #expect(medications.count == 1)
        #expect(medications[0].name == "Cached")
    }

    @Test("fetchAll network failure with empty cache throws APIError.network")
    func fetchAllNetworkFailureEmptyCache() async {
        let client = MockMedicationClient()
        let cache = MockCacheStore()
        client.getAllResult = .failure(URLError(.notConnectedToInternet))

        let repo = LiveMedicationRepository(apiClient: client, cache: cache)
        await #expect(throws: APIError.network) {
            try await repo.fetchAll(activeOnly: nil)
        }
    }

    @Test("fetchById 404 throws APIError.notFound")
    func fetchByIdNotFound() async {
        let client = MockMedicationClient()
        let cache = MockCacheStore()
        client.getByIdResult = .success(.notFound(.init(body: .any(HTTPBody(Data("{}".utf8))))))

        let repo = LiveMedicationRepository(apiClient: client, cache: cache)
        await #expect(throws: APIError.notFound) {
            try await repo.fetchById(1)
        }
    }

    @Test("fetchById success returns correct medication")
    func fetchByIdSuccess() async throws {
        let client = MockMedicationClient()
        let cache = MockCacheStore()
        let dto = Self.makeDTO(id: 5, name: "Metformin")
        client.getByIdResult = .success(try Self.makeOkSingleOutput(dto: dto))

        let repo = LiveMedicationRepository(apiClient: client, cache: cache)
        let med = try await repo.fetchById(5)

        #expect(med.id == 5)
        #expect(med.name == "Metformin")
    }

    @Test("create returns mapped domain model and invalidates cache")
    func createSuccess() async throws {
        let client = MockMedicationClient()
        let cache = MockCacheStore()
        cache.save([Medication](), forKey: "medications.list")
        let dto = Self.makeDTO(id: 10, name: "Ibuprofen")
        client.createResult = .success(try Self.makeCreatedOutput(dto: dto))

        let repo = LiveMedicationRepository(apiClient: client, cache: cache)
        let request = MedicationCreateRequest(
            name: "Ibuprofen", dosageText: nil, instructions: nil,
            startDate: Date(), endDate: nil, stockUnit: .tablet,
            doseQuantity: nil, lowStockThreshold: nil, currentStock: nil, catalogItemId: nil
        )
        let med = try await repo.create(request)

        #expect(client.createCallCount == 1)
        #expect(med.id == 10)
        #expect(med.name == "Ibuprofen")
        #expect(!cache.hasValue(forKey: "medications.list"))
    }

    @Test("create 400 throws APIError.validation")
    func createBadRequest() async {
        let client = MockMedicationClient()
        let cache = MockCacheStore()
        client.createResult = .success(.badRequest(.init(body: .any(HTTPBody(Data("{}".utf8))))))

        let repo = LiveMedicationRepository(apiClient: client, cache: cache)
        let request = MedicationCreateRequest(
            name: "", dosageText: nil, instructions: nil,
            startDate: Date(), endDate: nil, stockUnit: .tablet,
            doseQuantity: nil, lowStockThreshold: nil, currentStock: nil, catalogItemId: nil
        )
        await #expect(throws: APIError.validation(message: nil)) {
            try await repo.create(request)
        }
    }

    @Test("delete 204 succeeds and invalidates cache")
    func deleteSuccess() async throws {
        let client = MockMedicationClient()
        let cache = MockCacheStore()
        cache.save([Medication](), forKey: "medications.list")
        client.deleteResult = .success(.noContent(.init()))

        let repo = LiveMedicationRepository(apiClient: client, cache: cache)
        try await repo.delete(id: 1)

        #expect(client.deleteCallCount == 1)
        #expect(!cache.hasValue(forKey: "medications.list"))
    }

    @Test("delete 404 throws APIError.notFound")
    func deleteNotFound() async {
        let client = MockMedicationClient()
        let cache = MockCacheStore()
        client.deleteResult = .success(.notFound(.init()))

        let repo = LiveMedicationRepository(apiClient: client, cache: cache)
        await #expect(throws: APIError.notFound) {
            try await repo.delete(id: 99)
        }
    }
}
