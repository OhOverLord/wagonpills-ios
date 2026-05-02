import Foundation
import OpenAPIRuntime

// MARK: - Repository protocol

protocol MedicationRepository: Sendable {
    func fetchAll(activeOnly: Bool?) async throws -> [Medication]
    func fetchById(_ id: Int64) async throws -> Medication
}

// MARK: - Narrow client protocol

// Wraps only the two generated operations the repository needs.
// APIClient conforms via extension below; tests supply MockMedicationClient.
protocol MedicationClient: Sendable {
    func getMedications(activeOnly: Bool?) async throws -> Operations.GetAll3.Output
    func getMedication(id: Int64) async throws -> Operations.GetById5.Output
}

extension APIClient: MedicationClient {
    func getMedications(activeOnly: Bool?) async throws -> Operations.GetAll3.Output {
        try await client.getAll3(query: .init(active: activeOnly))
    }
    func getMedication(id: Int64) async throws -> Operations.GetById5.Output {
        try await client.getById5(path: .init(id: id))
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
}
