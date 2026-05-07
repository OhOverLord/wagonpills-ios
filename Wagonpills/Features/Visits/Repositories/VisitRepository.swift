import Foundation
import OpenAPIRuntime

// MARK: - Repository protocol

protocol VisitRepository: Sendable {
    func fetchAll() async throws -> [Visit]
    func fetchById(_ id: Int64) async throws -> Visit
    func create(_ request: VisitCreateRequest) async throws -> Visit
    func update(id: Int64, _ request: VisitUpdateRequest) async throws -> Visit
    func delete(id: Int64) async throws
    func uploadAttachment(
        visitId: Int64,
        data: Data,
        fileName: String,
        mimeType: String,
        note: String?
    ) async throws -> VisitAttachment
    func downloadAttachment(visitId: Int64, attachmentId: Int64) async throws -> Data
    func deleteAttachment(visitId: Int64, attachmentId: Int64) async throws
}

// MARK: - Narrow client protocol

protocol VisitClient: Sendable {
    func getVisits() async throws -> Operations.GetAll.Output
    func createVisit(_ body: Components.Schemas.CreateDoctorVisitRequest) async throws -> Operations.Create.Output
    func getVisit(id: Int64) async throws -> Operations.GetById.Output
    func updateVisit(id: Int64, _ body: Components.Schemas.UpdateDoctorVisitRequest) async throws -> Operations.Update.Output
    func deleteVisit(id: Int64) async throws -> Operations.Delete.Output
    func uploadVisitAttachment(
        visitId: Int64,
        note: String?,
        body: Operations.UploadAttachment.Input.Body
    ) async throws -> Operations.UploadAttachment.Output
    func downloadVisitAttachment(visitId: Int64, attachmentId: Int64) async throws -> Operations.DownloadAttachment.Output
    func deleteVisitAttachment(visitId: Int64, attachmentId: Int64) async throws -> Operations.DeleteAttachment.Output
}

extension APIClient: VisitClient {
    func getVisits() async throws -> Operations.GetAll.Output {
        try await client.getAll()
    }
    func createVisit(_ body: Components.Schemas.CreateDoctorVisitRequest) async throws -> Operations.Create.Output {
        try await client.create(body: .json(body))
    }
    func getVisit(id: Int64) async throws -> Operations.GetById.Output {
        try await client.getById(path: .init(id: id))
    }
    func updateVisit(
        id: Int64,
        _ body: Components.Schemas.UpdateDoctorVisitRequest
    ) async throws -> Operations.Update.Output {
        try await client.update(path: .init(id: id), body: .json(body))
    }
    func deleteVisit(id: Int64) async throws -> Operations.Delete.Output {
        try await client.delete(path: .init(id: id))
    }
    func uploadVisitAttachment(
        visitId: Int64,
        note: String?,
        body: Operations.UploadAttachment.Input.Body
    ) async throws -> Operations.UploadAttachment.Output {
        try await client.uploadAttachment(
            path: .init(id: visitId),
            query: .init(note: note),
            body: body
        )
    }
    func downloadVisitAttachment(
        visitId: Int64,
        attachmentId: Int64
    ) async throws -> Operations.DownloadAttachment.Output {
        try await client.downloadAttachment(path: .init(id: visitId, attachmentId: attachmentId))
    }
    func deleteVisitAttachment(
        visitId: Int64,
        attachmentId: Int64
    ) async throws -> Operations.DeleteAttachment.Output {
        try await client.deleteAttachment(path: .init(id: visitId, attachmentId: attachmentId))
    }
}

// MARK: - Live implementation

final class LiveVisitRepository: VisitRepository {
    private let apiClient: any VisitClient
    private let cache: any CacheStore
    private let decoder: JSONDecoder

    private static let listCacheKey = "visits.list"

    init(apiClient: any VisitClient, cache: any CacheStore) {
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
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        self.decoder = jsonDecoder
    }

    func fetchAll() async throws -> [Visit] {
        let cached = cache.load([Visit].self, forKey: Self.listCacheKey)
        do {
            let fresh = try await loadAllFromNetwork()
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

    func fetchById(_ id: Int64) async throws -> Visit {
        do {
            let output = try await apiClient.getVisit(id: id)
            switch output {
            case .ok(let response):
                let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
                return try decodeSingle(from: data)
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

    func create(_ request: VisitCreateRequest) async throws -> Visit {
        do {
            let output = try await apiClient.createVisit(request.toDTO())
            switch output {
            case .created(let response):
                let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
                let visit = try decodeSingle(from: data)
                cache.remove(forKey: Self.listCacheKey)
                return visit
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

    func update(id: Int64, _ request: VisitUpdateRequest) async throws -> Visit {
        do {
            let output = try await apiClient.updateVisit(id: id, request.toDTO())
            switch output {
            case .ok(let response):
                let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
                let visit = try decodeSingle(from: data)
                cache.remove(forKey: Self.listCacheKey)
                return visit
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
            let output = try await apiClient.deleteVisit(id: id)
            switch output {
            case .ok:
                cache.remove(forKey: Self.listCacheKey)
            case .undocumented(204, _):
                // Backend returns 204 No Content instead of 200 — treat as success
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

    func uploadAttachment(
        visitId: Int64,
        data: Data,
        fileName: String,
        mimeType: String,
        note: String?
    ) async throws -> VisitAttachment {
        do {
            let body: Operations.UploadAttachment.Input.Body = .multipartForm([
                .file(.init(
                    payload: .init(body: HTTPBody(data, length: .known(Int64(data.count)))),
                    filename: fileName
                ))
            ])
            let output = try await apiClient.uploadVisitAttachment(visitId: visitId, note: note, body: body)
            switch output {
            case .created(let response):
                let responseData = try await Data(collecting: try response.body.any, upTo: 1_024_000)
                let attachment = try decodeAttachment(from: responseData)
                cache.remove(forKey: Self.listCacheKey)
                return attachment
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

    func downloadAttachment(visitId: Int64, attachmentId: Int64) async throws -> Data {
        do {
            let output = try await apiClient.downloadVisitAttachment(visitId: visitId, attachmentId: attachmentId)
            switch output {
            case .ok(let response):
                return try await Data(collecting: try response.body.any, upTo: 50_000_000)
            case .undocumented(let status, _):
                throw APIError.server(status: status)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }

    func deleteAttachment(visitId: Int64, attachmentId: Int64) async throws {
        do {
            let output = try await apiClient.deleteVisitAttachment(visitId: visitId, attachmentId: attachmentId)
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
}

// MARK: - Private helpers

private extension LiveVisitRepository {
    func loadAllFromNetwork() async throws -> [Visit] {
        let output = try await apiClient.getVisits()
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 10_485_760)
            return try decodeList(from: data)
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func decodeList(from data: Data) throws -> [Visit] {
        let dtos: [Components.Schemas.DoctorVisitResponse]
        do {
            dtos = try decoder.decode([Components.Schemas.DoctorVisitResponse].self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try dtos.map { try Visit.from($0) }
    }

    func decodeSingle(from data: Data) throws -> Visit {
        let dto: Components.Schemas.DoctorVisitResponse
        do {
            dto = try decoder.decode(Components.Schemas.DoctorVisitResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try Visit.from(dto)
    }

    func decodeAttachment(from data: Data) throws -> VisitAttachment {
        let dto: Components.Schemas.AttachmentResponse
        do {
            dto = try decoder.decode(Components.Schemas.AttachmentResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try VisitAttachment.from(dto)
    }
}
