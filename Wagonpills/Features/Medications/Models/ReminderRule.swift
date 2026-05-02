import Foundation

struct ReminderRule: Identifiable, Equatable, Sendable, Codable {
    let id: Int64
    let repeatType: RepeatType
    let intervalDays: Int?
    let daysOfWeek: Set<Weekday>
    let active: Bool
    let times: [ReminderTime]
}

enum RepeatType: String, CaseIterable, Equatable, Sendable, Codable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case interval = "INTERVAL"

    var displayName: String {
        switch self {
        case .daily:    return String(localized: "Daily")
        case .weekly:   return String(localized: "Weekly")
        case .interval: return String(localized: "Every X Days")
        }
    }
}

enum Weekday: String, CaseIterable, Comparable, Equatable, Sendable, Codable {
    case monday    = "MON"
    case tuesday   = "TUE"
    case wednesday = "WED"
    case thursday  = "THU"
    case friday    = "FRI"
    case saturday  = "SAT"
    case sunday    = "SUN"

    var displayName: String {
        switch self {
        case .monday:    return String(localized: "Mon")
        case .tuesday:   return String(localized: "Tue")
        case .wednesday: return String(localized: "Wed")
        case .thursday:  return String(localized: "Thu")
        case .friday:    return String(localized: "Fri")
        case .saturday:  return String(localized: "Sat")
        case .sunday:    return String(localized: "Sun")
        }
    }

    var shortName: String {
        switch self {
        case .monday:    return "Mo"
        case .tuesday:   return "Tu"
        case .wednesday: return "We"
        case .thursday:  return "Th"
        case .friday:    return "Fr"
        case .saturday:  return "Sa"
        case .sunday:    return "Su"
        }
    }

    private var sortOrder: Int { Weekday.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.sortOrder < rhs.sortOrder }
}

struct ReminderTime: Identifiable, Equatable, Sendable, Codable {
    let id: Int64
    let hour: Int
    let minute: Int

    var displayString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var dateComponents: DateComponents {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return comps
    }
}

// MARK: - DTO Mapping

extension ReminderRule {
    static func from(
        _ dto: Components.Schemas.ReminderRuleResponse,
        times: [ReminderTime]
    ) throws -> ReminderRule {
        guard let id = dto.id else { throw APIError.decoding }
        guard let rawRepeat = dto.repeatType else { throw APIError.decoding }
        guard let repeatType = RepeatType(rawValue: rawRepeat.rawValue) else { throw APIError.decoding }
        guard let active = dto.active else { throw APIError.decoding }

        let daysOfWeek: Set<Weekday>
        if let daysStr = dto.daysOfWeek, !daysStr.isEmpty {
            var parsed = Set<Weekday>()
            for component in daysStr.split(separator: ",") {
                let trimmed = String(component).trimmingCharacters(in: .whitespaces)
                guard let day = Weekday(rawValue: trimmed) else { throw APIError.decoding }
                parsed.insert(day)
            }
            daysOfWeek = parsed
        } else {
            daysOfWeek = []
        }

        return ReminderRule(
            id: id,
            repeatType: repeatType,
            intervalDays: dto.intervalDays.map(Int.init),
            daysOfWeek: daysOfWeek,
            active: active,
            times: times
        )
    }
}

extension ReminderTime {
    static func from(_ dto: Components.Schemas.ReminderTimeResponse) throws -> ReminderTime {
        guard let id = dto.id else { throw APIError.decoding }
        guard let timeStr = dto.timeOfDay else { throw APIError.decoding }

        let parts = timeStr.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else { throw APIError.decoding }

        return ReminderTime(id: id, hour: hour, minute: minute)
    }
}
