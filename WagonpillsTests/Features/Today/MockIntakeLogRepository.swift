import Foundation
@testable import Wagonpills

final class MockIntakeLogRepository: IntakeLogRepository, @unchecked Sendable {
    var logIntakeResult: Result<IntakeLog, Error> = .failure(APIError.unexpected("not configured"))
    var fetchLogsResult: Result<[IntakeLog], Error> = .success([])

    private(set) var logIntakeCallCount = 0
    private(set) var lastLoggedMedicationId: Int64?
    private(set) var lastLoggedStatus: IntakeStatus?
    private(set) var lastLoggedNote: String?
    private(set) var fetchLogsCallCount = 0
    private(set) var lastFetchMedicationId: Int64??
    private(set) var lastFetchStatus: IntakeStatus??

    func logIntake(
        medicationId: Int64,
        scheduledTime: Date,
        status: IntakeStatus,
        note: String?
    ) async throws -> IntakeLog {
        logIntakeCallCount += 1
        lastLoggedMedicationId = medicationId
        lastLoggedStatus = status
        lastLoggedNote = note
        return try logIntakeResult.get()
    }

    func fetchLogs(
        medicationId: Int64?,
        from: Date?,
        to: Date?,
        status: IntakeStatus?,
        page: Int
    ) async throws -> IntakeLogPage {
        fetchLogsCallCount += 1
        lastFetchMedicationId = medicationId
        lastFetchStatus = status
        let logs = try fetchLogsResult.get()
        return IntakeLogPage(logs: logs, hasMore: false)
    }

    static func makeLog(
        id: Int64 = 1,
        medicationId: Int64 = 1,
        scheduledTime: Date = Date(),
        status: IntakeStatus = .taken
    ) -> IntakeLog {
        IntakeLog(
            id: id,
            medicationId: medicationId,
            scheduledTime: scheduledTime,
            status: status,
            note: nil,
            takenAt: status == .taken ? scheduledTime : nil
        )
    }
}
