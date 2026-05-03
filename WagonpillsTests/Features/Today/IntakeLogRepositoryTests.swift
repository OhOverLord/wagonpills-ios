import Foundation
import OpenAPIRuntime
import Testing
@testable import Wagonpills

// MARK: - MockIntakeLogClient

final class MockIntakeLogClient: IntakeLogClient, @unchecked Sendable {
    var createResult: Result<Operations.Create8.Output, Error> = .failure(
        APIError.unexpected("not configured")
    )
    var getResult: Result<Operations.GetFiltered.Output, Error> = .success(
        .ok(.init(body: .any(HTTPBody(Data("[]".utf8)))))
    )

    private(set) var createCallCount = 0
    private(set) var lastCreateBody: Components.Schemas.CreateIntakeLogRequest?
    private(set) var getCallCount = 0
    private(set) var lastGetMedicationId: Int64?
    private(set) var lastGetStatus: String?

    func createIntakeLog(
        _ body: Components.Schemas.CreateIntakeLogRequest
    ) async throws -> Operations.Create8.Output {
        createCallCount += 1
        lastCreateBody = body
        return try createResult.get()
    }

    func getIntakeLogs(
        medicationId: Int64?,
        status: String?,
        from: Date?,
        to: Date?
    ) async throws -> Operations.GetFiltered.Output {
        getCallCount += 1
        lastGetMedicationId = medicationId
        lastGetStatus = status
        return try getResult.get()
    }
}

// MARK: - Helpers

private extension IntakeLogRepositoryTests {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func makeLogDTO(
        id: Int64 = 1,
        medicationId: Int64 = 1,
        status: Components.Schemas.IntakeLogResponse.StatusPayload = .taken,
        scheduledAt: Date = Date()
    ) -> Components.Schemas.IntakeLogResponse {
        Components.Schemas.IntakeLogResponse(
            id: id,
            medicationId: medicationId,
            status: status,
            scheduledAt: scheduledAt
        )
    }

    static func makeCreatedOutput(dto: Components.Schemas.IntakeLogResponse) throws -> Operations.Create8.Output {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        return .created(.init(body: .any(HTTPBody(data, length: .known(Int64(data.count)), iterationBehavior: .multiple))))
    }

    static func makeOkListOutput(dtos: [Components.Schemas.IntakeLogResponse]) throws -> Operations.GetFiltered.Output {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dtos)
        return .ok(.init(body: .any(HTTPBody(data, length: .known(Int64(data.count)), iterationBehavior: .multiple))))
    }
}

// MARK: - Tests

@Suite("IntakeLogRepository")
struct IntakeLogRepositoryTests {
    @Test("logIntake maps 201 response to IntakeLog")
    func logIntake201MapsToIntakeLog() async throws {
        let client = MockIntakeLogClient()
        let cache = MockCacheStore()
        let scheduledAt = Date()
        let dto = makeLogDTO(id: 42, medicationId: 1, status: .taken, scheduledAt: scheduledAt)
        client.createResult = .success(try makeCreatedOutput(dto: dto))

        let repo = LiveIntakeLogRepository(apiClient: client, cache: cache)
        let log = try await repo.logIntake(
            medicationId: 1,
            scheduledTime: scheduledAt,
            status: .taken,
            note: nil
        )

        #expect(log.id == 42)
        #expect(log.medicationId == 1)
        #expect(log.status == .taken)
        #expect(client.createCallCount == 1)
    }

    @Test("logIntake maps 409 response to APIError.conflict")
    func logIntake409MapsToConflict() async {
        let client = MockIntakeLogClient()
        let cache = MockCacheStore()
        client.createResult = .success(.undocumented(statusCode: 409, .init()))

        let repo = LiveIntakeLogRepository(apiClient: client, cache: cache)
        await #expect(throws: APIError.conflict(message: nil)) {
            try await repo.logIntake(
                medicationId: 1,
                scheduledTime: Date(),
                status: .taken,
                note: nil
            )
        }
    }

    @Test("logIntake does not allow creating .missed logs")
    func logIntakeMissedThrowsLocally() async {
        let client = MockIntakeLogClient()
        let cache = MockCacheStore()

        let repo = LiveIntakeLogRepository(apiClient: client, cache: cache)
        await #expect(throws: APIError.validation(message: "MISSED status cannot be created from the client.")) {
            try await repo.logIntake(
                medicationId: 1,
                scheduledTime: Date(),
                status: .missed,
                note: nil
            )
        }
        #expect(client.createCallCount == 0)
    }

    @Test("fetchLogs sends correct query parameters")
    func fetchLogsSendsQueryParams() async throws {
        let client = MockIntakeLogClient()
        let cache = MockCacheStore()
        let from = Calendar.current.startOfDay(for: Date())

        let repo = LiveIntakeLogRepository(apiClient: client, cache: cache)
        _ = try await repo.fetchLogs(
            medicationId: 7,
            from: from,
            to: nil,
            status: .taken
        )

        #expect(client.getCallCount == 1)
        #expect(client.lastGetMedicationId == 7)
        #expect(client.lastGetStatus == "TAKEN")
    }

    @Test("fetchLogs uses cache on repeated calls with same parameters")
    func fetchLogsUsesCache() async throws {
        let client = MockIntakeLogClient()
        let cache = MockCacheStore()
        let from = Calendar.current.startOfDay(for: Date())
        let dto = makeLogDTO()
        client.getResult = .success(try makeOkListOutput(dtos: [dto]))

        let repo = LiveIntakeLogRepository(apiClient: client, cache: cache)

        _ = try await repo.fetchLogs(medicationId: nil, from: from, to: nil, status: nil)
        #expect(client.getCallCount == 1)

        _ = try await repo.fetchLogs(medicationId: nil, from: from, to: nil, status: nil)
        #expect(client.getCallCount == 1)
    }
}
