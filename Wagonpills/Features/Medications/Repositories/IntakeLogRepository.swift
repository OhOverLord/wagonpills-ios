import Foundation
import OpenAPIRuntime

// MARK: - Repository protocol

protocol IntakeLogRepository: Sendable {
    func logIntake(
        medicationId: Int64,
        scheduledTime: Date,
        status: IntakeStatus,
        note: String?
    ) async throws -> IntakeLog

    func fetchLogs(
        medicationId: Int64?,
        from: Date?,
        to: Date?,
        status: IntakeStatus?
    ) async throws -> [IntakeLog]
}

// MARK: - Narrow client protocol

protocol IntakeLogClient: Sendable {
    func createIntakeLog(
        _ body: Components.Schemas.CreateIntakeLogRequest
    ) async throws -> Operations.Create8.Output

    func getIntakeLogs(
        medicationId: Int64?,
        status: String?,
        from: Date?,
        to: Date?
    ) async throws -> Operations.GetFiltered.Output
}

extension APIClient: IntakeLogClient {
    func createIntakeLog(
        _ body: Components.Schemas.CreateIntakeLogRequest
    ) async throws -> Operations.Create8.Output {
        try await client.create8(body: .json(body))
    }

    func getIntakeLogs(
        medicationId: Int64?,
        status: String?,
        from: Date?,
        to: Date?
    ) async throws -> Operations.GetFiltered.Output {
        let statusPayload = status.flatMap {
            Operations.GetFiltered.Input.Query.StatusPayload(rawValue: $0)
        }
        return try await client.getFiltered(query: .init(
            medicationId: medicationId,
            status: statusPayload,
            from: from,
            to: to
        ))
    }
}

// MARK: - Live implementation

final class LiveIntakeLogRepository: IntakeLogRepository {
    private let apiClient: any IntakeLogClient
    private let cache: any CacheStore

    init(apiClient: any IntakeLogClient, cache: any CacheStore) {
        self.apiClient = apiClient
        self.cache = cache
    }

    func logIntake(
        medicationId: Int64,
        scheduledTime: Date,
        status: IntakeStatus,
        note: String?
    ) async throws -> IntakeLog {
        guard status != .missed else {
            throw APIError.validation(message: "MISSED status cannot be created from the client.")
        }
        guard let statusDTO = Components.Schemas.CreateIntakeLogRequest.StatusPayload(rawValue: status.rawValue) else {
            throw APIError.unexpected("Cannot map intake status: \(status.rawValue)")
        }

        let body = Components.Schemas.CreateIntakeLogRequest(
            medicationId: medicationId,
            status: statusDTO,
            scheduledAt: scheduledTime,
            note: note
        )

        let output = try await apiClient.createIntakeLog(body)
        switch output {
        case .created(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            let log = try decodeLog(from: data)
            // Invalidate today's cached log list so the next load() fetches fresh data.
            cache.remove(forKey: cacheKey(medicationId: nil, from: Date()))
            cache.remove(forKey: cacheKey(medicationId: medicationId, from: Date()))
            return log
        case .badRequest:
            throw APIError.validation(message: nil)
        case .notFound:
            throw APIError.notFound
        case .undocumented(let statusCode, _):
            if statusCode == 409 { throw APIError.conflict(message: nil) }
            throw APIError.server(status: statusCode)
        }
    }

    func fetchLogs(
        medicationId: Int64?,
        from: Date?,
        to: Date?,
        status: IntakeStatus?
    ) async throws -> [IntakeLog] {
        // Only cache the unfiltered today-view query (used by TodayViewModel).
        // History queries vary by date range and status — caching them risks
        // serving stale results after a new intake is logged.
        let isTodayQuery = medicationId == nil && status == nil && isTodayStart(from)
        let key = cacheKey(medicationId: medicationId, from: from)

        if isTodayQuery, let cached = cache.load([IntakeLog].self, forKey: key) {
            return cached
        }

        let output = try await apiClient.getIntakeLogs(
            medicationId: medicationId,
            status: status?.rawValue,
            from: from,
            to: to
        )

        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 10_485_760)
            let logs = try decodeLogList(from: data)
            if isTodayQuery { cache.save(logs, forKey: key) }
            return logs
        case .undocumented(let statusCode, _):
            if statusCode == 401 { throw APIError.unauthorized }
            throw APIError.server(status: statusCode)
        }
    }
}

// MARK: - Private helpers

private extension LiveIntakeLogRepository {
    func isTodayStart(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date) &&
               Calendar.current.startOfDay(for: date) == date
    }

    func cacheKey(medicationId: Int64?, from: Date?) -> String {
        let medPart = medicationId.map { String($0) } ?? "all"
        let dayPart = from.map { Self.dayFormatter.string(from: $0) } ?? "any"
        return "intakelogs.\(medPart).\(dayPart)"
    }

    func decodeLog(from data: Data) throws -> IntakeLog {
        let dto: Components.Schemas.IntakeLogResponse
        do {
            dto = try Self.decoder.decode(Components.Schemas.IntakeLogResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try IntakeLog.from(dto)
    }

    func decodeLogList(from data: Data) throws -> [IntakeLog] {
        let dtos: [Components.Schemas.IntakeLogResponse]
        do {
            dtos = try Self.decoder.decode([Components.Schemas.IntakeLogResponse].self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try dtos.map { try IntakeLog.from($0) }
    }

    static let decoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .custom { codingDecoder in
            let container = try codingDecoder.singleValueContainer()
            let string = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        return jsonDecoder
    }()

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
