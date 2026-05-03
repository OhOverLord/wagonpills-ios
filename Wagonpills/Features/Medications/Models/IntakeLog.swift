import Foundation

struct IntakeLog: Identifiable, Equatable, Sendable, Codable {
    let id: Int64
    let medicationId: Int64
    let scheduledTime: Date
    let status: IntakeStatus
    let note: String?
    let takenAt: Date?
}

enum IntakeStatus: String, Equatable, Sendable, Codable {
    case taken = "TAKEN"
    case skipped = "SKIPPED"
    case missed = "MISSED"
}

// Computed on the fly from the schedule + today's intake logs. Not persisted.
struct TodayDose: Identifiable, Equatable {
    // Stable key: "\(medicationId).\(ruleId).\(timeId)"
    let id: String
    let medicationId: Int64
    let medicationName: String
    let scheduledTime: Date
    let doseQuantity: Double?
    let stockUnit: StockUnit
    var log: IntakeLog?
}

// MARK: - DTO mapping

extension IntakeLog {
    static func from(_ dto: Components.Schemas.IntakeLogResponse) throws -> IntakeLog {
        guard let id = dto.id else { throw APIError.decoding }
        guard let medicationId = dto.medicationId else { throw APIError.decoding }
        guard let rawStatus = dto.status else { throw APIError.decoding }
        guard let status = IntakeStatus(rawValue: rawStatus.rawValue) else { throw APIError.decoding }
        guard let scheduledAtDate = dto.scheduledAt else { throw APIError.decoding }

        return IntakeLog(
            id: id,
            medicationId: medicationId,
            scheduledTime: scheduledAtDate,
            status: status,
            note: dto.note,
            takenAt: dto.takenAt
        )
    }
}
