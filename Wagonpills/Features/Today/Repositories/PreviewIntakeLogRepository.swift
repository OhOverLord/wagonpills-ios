#if DEBUG
import Foundation

struct PreviewIntakeLogRepository: IntakeLogRepository {
    var logs: [IntakeLog]
    var logIntakeResult: Result<IntakeLog, APIError>?
    var error: APIError?

    init(logs: [IntakeLog] = [], error: APIError? = nil) {
        self.logs = logs
        self.error = error
    }

    func logIntake(
        medicationId: Int64,
        scheduledTime: Date,
        status: IntakeStatus,
        note: String?
    ) async throws -> IntakeLog {
        if let result = logIntakeResult { return try result.get() }
        if let error { throw error }
        return IntakeLog(
            id: Int64.random(in: 1000...9999),
            medicationId: medicationId,
            scheduledTime: scheduledTime,
            status: status,
            note: note,
            takenAt: status == .taken ? Date() : nil
        )
    }

    func fetchLogs(
        medicationId: Int64?,
        from: Date?,
        to: Date?,
        status: IntakeStatus?
    ) async throws -> [IntakeLog] {
        if let error { throw error }
        return logs.filter { log in
            if let id = medicationId, log.medicationId != id { return false }
            if let from, log.scheduledTime < from { return false }
            if let to, log.scheduledTime >= to { return false }
            if let status, log.status != status { return false }
            return true
        }
    }
    static func makeSampleLogs(medicationId: Int64 = 1) -> [IntakeLog] {
        let calendar = Calendar.current
        let now = Date()
        var result: [IntakeLog] = []
        var id: Int64 = 1
        let statuses: [IntakeStatus] = [.taken, .skipped, .missed]
        for dayOffset in 0..<10 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            for (idx, hour) in [8, 14, 20].enumerated() {
                var comps = calendar.dateComponents([.year, .month, .day], from: day)
                comps.hour = hour
                comps.minute = 0
                guard let scheduled = calendar.date(from: comps) else { continue }
                let status = statuses[idx % statuses.count]
                result.append(IntakeLog(
                    id: id,
                    medicationId: medicationId,
                    scheduledTime: scheduled,
                    status: status,
                    note: status == .skipped ? "Felt nauseous" : nil,
                    takenAt: status == .taken ? scheduled : nil
                ))
                id += 1
            }
        }
        return result
    }
}
#endif
