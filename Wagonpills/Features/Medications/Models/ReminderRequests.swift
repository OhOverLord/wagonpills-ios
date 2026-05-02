import Foundation

struct ReminderRuleCreateRequest {
    let repeatType: RepeatType
    let intervalDays: Int?
    let daysOfWeek: Set<Weekday>
}

struct ReminderRuleUpdateRequest {
    let repeatType: RepeatType
    let intervalDays: Int?
    let daysOfWeek: Set<Weekday>
    let active: Bool
}

// MARK: - DTO mapping

extension ReminderRuleCreateRequest {
    func toDTO() -> Components.Schemas.CreateReminderRuleRequest {
        Components.Schemas.CreateReminderRuleRequest(
            repeatType: .init(rawValue: repeatType.rawValue) ?? .daily,
            intervalDays: intervalDays.map(Int32.init),
            daysOfWeek: daysStr
        )
    }

    private var daysStr: String? {
        guard !daysOfWeek.isEmpty else { return nil }
        return daysOfWeek.sorted().map(\.rawValue).joined(separator: ",")
    }
}

extension ReminderRuleUpdateRequest {
    func toDTO() -> Components.Schemas.UpdateReminderRuleRequest {
        Components.Schemas.UpdateReminderRuleRequest(
            repeatType: .init(rawValue: repeatType.rawValue),
            intervalDays: intervalDays.map(Int32.init),
            daysOfWeek: daysStr,
            active: active
        )
    }

    private var daysStr: String? {
        guard !daysOfWeek.isEmpty else { return nil }
        return daysOfWeek.sorted().map(\.rawValue).joined(separator: ",")
    }
}
