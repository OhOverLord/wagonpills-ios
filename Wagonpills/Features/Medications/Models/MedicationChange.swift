import Foundation

enum MedicationChangeType: String, CaseIterable, Sendable {
    case start          = "START"
    case stop           = "STOP"
    case dosageChange   = "DOSAGE_CHANGE"
    case scheduleChange = "SCHEDULE_CHANGE"

    var displayName: String {
        switch self {
        case .start:          return "Started"
        case .stop:           return "Stopped"
        case .dosageChange:   return "Dosage Changed"
        case .scheduleChange: return "Schedule Changed"
        }
    }

    var color: String {
        switch self {
        case .start:          return "green"
        case .stop:           return "red"
        case .dosageChange:   return "orange"
        case .scheduleChange: return "blue"
        }
    }
}

struct MedicationChange: Identifiable, Equatable, Sendable {
    let id: Int64
    let medicationId: Int64
    let medicationName: String
    let doctorVisitId: Int64?
    let changeType: MedicationChangeType
    let oldValue: String?
    let newValue: String?
    let reason: String?
    let changedAt: Date
}

// MARK: - DTO mapping

extension MedicationChange {
    static func from(_ dto: Components.Schemas.MedicationChangeResponse) throws -> MedicationChange {
        guard let id = dto.id else { throw APIError.decoding }
        guard let medicationId = dto.medicationId else { throw APIError.decoding }
        guard let medicationName = dto.medicationName else { throw APIError.decoding }
        guard let rawType = dto.changeType else { throw APIError.decoding }
        guard let changedAt = dto.changedAt else { throw APIError.decoding }

        let changeType: MedicationChangeType
        if let parsed = MedicationChangeType(rawValue: rawType.rawValue) {
            changeType = parsed
        } else {
            #if DEBUG
            print("[MedicationChange] Unknown changeType '\(rawType.rawValue)', falling back to .dosageChange")
            #endif
            changeType = .dosageChange
        }

        return MedicationChange(
            id: id,
            medicationId: medicationId,
            medicationName: medicationName,
            doctorVisitId: dto.doctorVisitId,
            changeType: changeType,
            oldValue: dto.oldValue,
            newValue: dto.newValue,
            reason: dto.reason,
            changedAt: changedAt
        )
    }
}
