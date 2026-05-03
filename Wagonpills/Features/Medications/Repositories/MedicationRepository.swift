import Foundation
import OpenAPIRuntime

// MARK: - Repository protocol

protocol MedicationRepository: Sendable {
    func fetchAll(activeOnly: Bool?) async throws -> [Medication]
    func fetchById(_ id: Int64) async throws -> Medication
    func create(_ request: MedicationCreateRequest) async throws -> Medication
    func update(id: Int64, _ request: MedicationUpdateRequest) async throws -> Medication
    func delete(id: Int64) async throws
    func addStock(medicationId: Int64, quantity: Double, note: String?) async throws
    func adjustStock(medicationId: Int64, quantity: Double, note: String?) async throws
    func fetchStockSummary(medicationId: Int64) async throws -> StockSummary
    func fetchStockHistory(medicationId: Int64) async throws -> [StockMovement]
}

// MARK: - Narrow client protocol

// Wraps only the generated operations the repository needs.
// APIClient conforms via extension below; tests supply MockMedicationClient.
protocol MedicationClient: Sendable {
    func getMedications(activeOnly: Bool?) async throws -> Operations.GetAll3.Output
    func getMedication(id: Int64) async throws -> Operations.GetById5.Output
    func createMedication(_ body: Components.Schemas.CreateMedicationRequest) async throws -> Operations.Create4.Output
    func updateMedication(id: Int64, _ body: Components.Schemas.UpdateMedicationRequest) async throws -> Operations.Update6.Output
    func deleteMedication(id: Int64) async throws -> Operations.Delete6.Output
    func addStock(medicationId: Int64, _ body: Components.Schemas.AddStockRequest) async throws -> Operations.AddStock.Output
    func adjustStock(medicationId: Int64, _ body: Components.Schemas.AdjustStockRequest) async throws -> Operations.AdjustStock.Output
    func getStockSummary(medicationId: Int64) async throws -> Operations.GetSummary.Output
    func getStockHistory(medicationId: Int64) async throws -> Operations.GetHistory.Output
}

extension APIClient: MedicationClient {
    func getMedications(activeOnly: Bool?) async throws -> Operations.GetAll3.Output {
        try await client.getAll3(query: .init(active: activeOnly))
    }
    func getMedication(id: Int64) async throws -> Operations.GetById5.Output {
        try await client.getById5(path: .init(id: id))
    }
    func createMedication(_ body: Components.Schemas.CreateMedicationRequest) async throws -> Operations.Create4.Output {
        try await client.create4(body: .json(body))
    }
    func updateMedication(id: Int64, _ body: Components.Schemas.UpdateMedicationRequest) async throws -> Operations.Update6.Output {
        try await client.update6(path: .init(id: id), body: .json(body))
    }
    func deleteMedication(id: Int64) async throws -> Operations.Delete6.Output {
        try await client.delete6(path: .init(id: id))
    }
    func addStock(medicationId: Int64, _ body: Components.Schemas.AddStockRequest) async throws -> Operations.AddStock.Output {
        try await client.addStock(path: .init(medicationId: medicationId), body: .json(body))
    }
    func adjustStock(medicationId: Int64, _ body: Components.Schemas.AdjustStockRequest) async throws -> Operations.AdjustStock.Output {
        try await client.adjustStock(path: .init(medicationId: medicationId), body: .json(body))
    }
    func getStockSummary(medicationId: Int64) async throws -> Operations.GetSummary.Output {
        try await client.getSummary(path: .init(medicationId: medicationId))
    }
    func getStockHistory(medicationId: Int64) async throws -> Operations.GetHistory.Output {
        try await client.getHistory(path: .init(medicationId: medicationId))
    }
}

// MARK: - Live implementation

final class LiveMedicationRepository: MedicationRepository {
    private let apiClient: any MedicationClient
    private let cache: any CacheStore
    private let decoder: JSONDecoder

    private static let listCacheKey = "medications.list"

    init(apiClient: any MedicationClient, cache: any CacheStore) {
        self.apiClient = apiClient
        self.cache = cache

        // date-time fields in MedicationResponse are Foundation.Date; use ISO8601 strategy.
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .custom { codingDecoder in
            let container = try codingDecoder.singleValueContainer()
            let string = try container.decode(String.self)
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: string) { return date }
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        self.decoder = jsonDecoder
    }

    // Cache-first with network fallback. Returning stale data on network failure is
    // intentional: the UI shows a banner so the user knows the data may be outdated.
    func fetchAll(activeOnly: Bool?) async throws -> [Medication] {
        let cached = cache.load([Medication].self, forKey: Self.listCacheKey)

        do {
            let fresh = try await loadFromNetwork(activeOnly: activeOnly)
            cache.save(fresh, forKey: Self.listCacheKey)
            return fresh
        } catch let error as APIError {
            if let cached { return cached }
            throw error
        } catch {
            if let cached { return cached }
            throw APIError.from(error)
        }
    }

    func fetchById(_ id: Int64) async throws -> Medication {
        let output = try await apiClient.getMedication(id: id)
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            return try decodeSingle(from: data)
        case .notFound:
            throw APIError.notFound
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func create(_ request: MedicationCreateRequest) async throws -> Medication {
        let output = try await apiClient.createMedication(request.toDTO())
        switch output {
        case .created(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            let medication = try decodeSingle(from: data)
            cache.remove(forKey: Self.listCacheKey)
            return medication
        case .badRequest:
            throw APIError.validation(message: nil)
        case .unauthorized:
            throw APIError.unauthorized
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func update(id: Int64, _ request: MedicationUpdateRequest) async throws -> Medication {
        let output = try await apiClient.updateMedication(id: id, request.toDTO())
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            let medication = try decodeSingle(from: data)
            cache.remove(forKey: Self.listCacheKey)
            return medication
        case .notFound:
            throw APIError.notFound
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func delete(id: Int64) async throws {
        let output = try await apiClient.deleteMedication(id: id)
        switch output {
        case .noContent:
            cache.remove(forKey: Self.listCacheKey)
        case .notFound:
            throw APIError.notFound
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func addStock(medicationId: Int64, quantity: Double, note: String?) async throws {
        let body = Components.Schemas.AddStockRequest(quantity: quantity, note: note)
        let output = try await apiClient.addStock(medicationId: medicationId, body)
        switch output {
        case .created:
            cache.remove(forKey: Self.listCacheKey)
        case .notFound:
            throw APIError.notFound
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func adjustStock(medicationId: Int64, quantity: Double, note: String?) async throws {
        let body = Components.Schemas.AdjustStockRequest(quantity: quantity, note: note)
        let output = try await apiClient.adjustStock(medicationId: medicationId, body)
        switch output {
        case .created:
            cache.remove(forKey: Self.listCacheKey)
        case .notFound:
            throw APIError.notFound
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func fetchStockSummary(medicationId: Int64) async throws -> StockSummary {
        let output = try await apiClient.getStockSummary(medicationId: medicationId)
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            return try decodeStockSummary(from: data)
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func fetchStockHistory(medicationId: Int64) async throws -> [StockMovement] {
        let output = try await apiClient.getStockHistory(medicationId: medicationId)
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 5_242_880)
            return try decodeStockHistory(from: data)
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }
}

// MARK: - Private helpers

private extension LiveMedicationRepository {
    func loadFromNetwork(activeOnly: Bool?) async throws -> [Medication] {
        let output = try await apiClient.getMedications(activeOnly: activeOnly)
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 10_485_760)
            return try decodeList(from: data)
        case .unauthorized:
            throw APIError.unauthorized
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func decodeList(from data: Data) throws -> [Medication] {
        let dtos: [Components.Schemas.MedicationResponse]
        do {
            dtos = try decoder.decode([Components.Schemas.MedicationResponse].self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try dtos.map { try Medication.from($0) }
    }

    func decodeSingle(from data: Data) throws -> Medication {
        let dto: Components.Schemas.MedicationResponse
        do {
            dto = try decoder.decode(Components.Schemas.MedicationResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try Medication.from(dto)
    }

    func decodeStockSummary(from data: Data) throws -> StockSummary {
        let dto: Components.Schemas.StockSummaryResponse
        do {
            dto = try decoder.decode(Components.Schemas.StockSummaryResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try StockSummary.from(dto)
    }

    func decodeStockHistory(from data: Data) throws -> [StockMovement] {
        let dtos: [Components.Schemas.StockMovementResponse]
        do {
            dtos = try decoder.decode([Components.Schemas.StockMovementResponse].self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try dtos.map { try StockMovement.from($0) }
    }
}
