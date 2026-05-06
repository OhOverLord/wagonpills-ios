import Foundation
import OpenAPIRuntime

// MARK: - Repository protocol

protocol PrescriptionRepository: Sendable {
    func fetchAll() async throws -> [Prescription]
    func fetchById(_ id: Int64) async throws -> Prescription
    func create(_ request: PrescriptionCreateRequest) async throws -> Prescription
    func update(id: Int64, _ request: PrescriptionUpdateRequest) async throws -> Prescription
    func delete(id: Int64) async throws
    func fetchItems(prescriptionId: Int64) async throws -> [PrescriptionItem]
    func createItem(
        prescriptionId: Int64,
        _ request: PrescriptionItemCreateRequest
    ) async throws -> PrescriptionItem
    func updateItem(
        prescriptionId: Int64,
        itemId: Int64,
        _ request: PrescriptionItemUpdateRequest
    ) async throws -> PrescriptionItem
    func deleteItem(prescriptionId: Int64, itemId: Int64) async throws
}

// MARK: - Narrow client protocol

protocol PrescriptionClient: Sendable {
    func getPrescriptions() async throws -> Operations.GetAll2.Output
    func createPrescription(
        _ body: Components.Schemas.CreatePrescriptionRequest
    ) async throws -> Operations.Create2.Output
    func getPrescription(id: Int64) async throws -> Operations.GetById2.Output
    func updatePrescription(
        id: Int64,
        _ body: Components.Schemas.UpdatePrescriptionRequest
    ) async throws -> Operations.Update3.Output
    func deletePrescription(id: Int64) async throws -> Operations.Delete3.Output
    func getPrescriptionItems(prescriptionId: Int64) async throws -> Operations.GetByPrescription.Output
    func createPrescriptionItem(
        prescriptionId: Int64,
        _ body: Components.Schemas.CreatePrescriptionItemRequest
    ) async throws -> Operations.Create3.Output
    func updatePrescriptionItem(
        prescriptionId: Int64,
        itemId: Int64,
        _ body: Components.Schemas.UpdatePrescriptionItemRequest
    ) async throws -> Operations.Update2.Output
    func deletePrescriptionItem(
        prescriptionId: Int64,
        itemId: Int64
    ) async throws -> Operations.Delete2.Output
}

extension APIClient: PrescriptionClient {
    func getPrescriptions() async throws -> Operations.GetAll2.Output {
        try await client.getAll2()
    }
    func createPrescription(
        _ body: Components.Schemas.CreatePrescriptionRequest
    ) async throws -> Operations.Create2.Output {
        try await client.create2(body: .json(body))
    }
    func getPrescription(id: Int64) async throws -> Operations.GetById2.Output {
        try await client.getById2(path: .init(id: id))
    }
    func updatePrescription(
        id: Int64,
        _ body: Components.Schemas.UpdatePrescriptionRequest
    ) async throws -> Operations.Update3.Output {
        try await client.update3(path: .init(id: id), body: .json(body))
    }
    func deletePrescription(id: Int64) async throws -> Operations.Delete3.Output {
        try await client.delete3(path: .init(id: id))
    }
    func getPrescriptionItems(
        prescriptionId: Int64
    ) async throws -> Operations.GetByPrescription.Output {
        try await client.getByPrescription(path: .init(prescriptionId: prescriptionId))
    }
    func createPrescriptionItem(
        prescriptionId: Int64,
        _ body: Components.Schemas.CreatePrescriptionItemRequest
    ) async throws -> Operations.Create3.Output {
        try await client.create3(path: .init(prescriptionId: prescriptionId), body: .json(body))
    }
    func updatePrescriptionItem(
        prescriptionId: Int64,
        itemId: Int64,
        _ body: Components.Schemas.UpdatePrescriptionItemRequest
    ) async throws -> Operations.Update2.Output {
        try await client.update2(
            path: .init(prescriptionId: prescriptionId, itemId: itemId),
            body: .json(body)
        )
    }
    func deletePrescriptionItem(
        prescriptionId: Int64,
        itemId: Int64
    ) async throws -> Operations.Delete2.Output {
        try await client.delete2(path: .init(prescriptionId: prescriptionId, itemId: itemId))
    }
}

// MARK: - Live implementation

final class LivePrescriptionRepository: PrescriptionRepository {
    private let apiClient: any PrescriptionClient
    private let cache: any CacheStore
    private let decoder: JSONDecoder

    private static let listCacheKey = "prescriptions.list"

    init(apiClient: any PrescriptionClient, cache: any CacheStore) {
        self.apiClient = apiClient
        self.cache = cache

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .custom { codingDecoder in
            let container = try codingDecoder.singleValueContainer()
            let string = try container.decode(String.self)
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: string) { return date }
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: string) { return date }
            // date-only format used for issuedAt (format: date in spec)
            isoFormatter.formatOptions = [.withFullDate]
            if let date = isoFormatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        self.decoder = jsonDecoder
    }

    func fetchAll() async throws -> [Prescription] {
        let cached = cache.load([Prescription].self, forKey: Self.listCacheKey)
        do {
            let bare = try await loadAllFromNetwork()
            let fresh = await withItemsAttached(to: bare)
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

    private func withItemsAttached(to prescriptions: [Prescription]) async -> [Prescription] {
        await withTaskGroup(of: (Int, [PrescriptionItem]).self) { group in
            for (index, prescription) in prescriptions.enumerated() {
                group.addTask {
                    let items = (try? await self.fetchItems(prescriptionId: prescription.id)) ?? []
                    return (index, items)
                }
            }
            var result = prescriptions
            for await (index, items) in group {
                result[index].items = items
            }
            return result
        }
    }

    func fetchById(_ id: Int64) async throws -> Prescription {
        do {
            let output = try await apiClient.getPrescription(id: id)
            switch output {
            case .ok(let response):
                let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
                var prescription = try decodeSingle(from: data)
                prescription.items = try await fetchItems(prescriptionId: id)
                return prescription
            case .undocumented(let status, _):
                throw APIError.server(status: status)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }

    func create(_ request: PrescriptionCreateRequest) async throws -> Prescription {
        do {
            let output = try await apiClient.createPrescription(request.toDTO())
            switch output {
            case .created(let response):
                let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
                let prescription = try decodeSingle(from: data)
                cache.remove(forKey: Self.listCacheKey)
                return prescription
            case .badRequest:
                throw APIError.validation(message: nil)
            case .undocumented(let status, _):
                throw APIError.server(status: status)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }

    func update(id: Int64, _ request: PrescriptionUpdateRequest) async throws -> Prescription {
        do {
            let output = try await apiClient.updatePrescription(id: id, request.toDTO())
            switch output {
            case .ok(let response):
                let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
                let prescription = try decodeSingle(from: data)
                cache.remove(forKey: Self.listCacheKey)
                return prescription
            case .undocumented(let status, _):
                throw APIError.server(status: status)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }

    func delete(id: Int64) async throws {
        do {
            let output = try await apiClient.deletePrescription(id: id)
            switch output {
            case .ok:
                cache.remove(forKey: Self.listCacheKey)
            case .undocumented(let status, _):
                throw APIError.server(status: status)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }

    func fetchItems(prescriptionId: Int64) async throws -> [PrescriptionItem] {
        do {
            let output = try await apiClient.getPrescriptionItems(prescriptionId: prescriptionId)
            switch output {
            case .ok(let response):
                let data = try await Data(collecting: try response.body.any, upTo: 5_242_880)
                return try decodeItemList(from: data)
            case .undocumented(let status, _):
                throw APIError.server(status: status)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }

    func createItem(
        prescriptionId: Int64,
        _ request: PrescriptionItemCreateRequest
    ) async throws -> PrescriptionItem {
        do {
            let output = try await apiClient.createPrescriptionItem(
                prescriptionId: prescriptionId,
                request.toDTO()
            )
            switch output {
            case .created(let response):
                let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
                return try decodeItemSingle(from: data)
            case .notFound:
                throw APIError.notFound
            case .undocumented(let status, _):
                throw APIError.server(status: status)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }

    func updateItem(
        prescriptionId: Int64,
        itemId: Int64,
        _ request: PrescriptionItemUpdateRequest
    ) async throws -> PrescriptionItem {
        do {
            let output = try await apiClient.updatePrescriptionItem(
                prescriptionId: prescriptionId,
                itemId: itemId,
                request.toDTO()
            )
            switch output {
            case .ok(let response):
                let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
                return try decodeItemSingle(from: data)
            case .undocumented(let status, _):
                throw APIError.server(status: status)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }

    func deleteItem(prescriptionId: Int64, itemId: Int64) async throws {
        do {
            let output = try await apiClient.deletePrescriptionItem(
                prescriptionId: prescriptionId,
                itemId: itemId
            )
            switch output {
            case .ok:
                break
            case .undocumented(let status, _):
                throw APIError.server(status: status)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }
}

// MARK: - Private helpers

private extension LivePrescriptionRepository {
    func loadAllFromNetwork() async throws -> [Prescription] {
        let output = try await apiClient.getPrescriptions()
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 10_485_760)
            return try decodeList(from: data)
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func decodeList(from data: Data) throws -> [Prescription] {
        let dtos: [Components.Schemas.PrescriptionResponse]
        do {
            dtos = try decoder.decode([Components.Schemas.PrescriptionResponse].self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try dtos.map { try Prescription.from($0) }
    }

    func decodeSingle(from data: Data) throws -> Prescription {
        let dto: Components.Schemas.PrescriptionResponse
        do {
            dto = try decoder.decode(Components.Schemas.PrescriptionResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try Prescription.from(dto)
    }

    func decodeItemList(from data: Data) throws -> [PrescriptionItem] {
        let dtos: [Components.Schemas.PrescriptionItemResponse]
        do {
            dtos = try decoder.decode([Components.Schemas.PrescriptionItemResponse].self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try dtos.map { try PrescriptionItem.from($0) }
    }

    func decodeItemSingle(from data: Data) throws -> PrescriptionItem {
        let dto: Components.Schemas.PrescriptionItemResponse
        do {
            dto = try decoder.decode(Components.Schemas.PrescriptionItemResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try PrescriptionItem.from(dto)
    }
}
