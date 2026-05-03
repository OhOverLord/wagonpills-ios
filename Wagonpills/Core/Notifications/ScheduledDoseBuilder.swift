import Foundation

struct ScheduledDose: Equatable, Sendable {
    let medicationId: Int64
    let medicationName: String
    let fireDate: DateComponents
    let ruleId: Int64
    let timeId: Int64
}

enum ScheduledDoseBuilder {
    /// Returns all scheduled doses within the window [from, from + days).
    static func build(
        medicationId: Int64,
        medicationName: String,
        rule: ReminderRule,
        from: Date,
        days: Int,
        calendar: Calendar = .current
    ) -> [ScheduledDose] {
        guard days > 0, !rule.times.isEmpty else { return [] }

        let windowStart = calendar.startOfDay(for: from)
        var doses: [ScheduledDose] = []

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: windowStart) else { continue }
            guard dayMatches(rule: rule, date: date, dayOffset: dayOffset, calendar: calendar) else { continue }

            let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)

            for time in rule.times {
                var fireDate = dayComponents
                fireDate.hour = time.hour
                fireDate.minute = time.minute
                fireDate.second = 0

                doses.append(ScheduledDose(
                    medicationId: medicationId,
                    medicationName: medicationName,
                    fireDate: fireDate,
                    ruleId: rule.id,
                    timeId: time.id
                ))
            }
        }

        return doses.sorted { lhs, rhs in
            guard
                let lhsDate = calendar.date(from: lhs.fireDate),
                let rhsDate = calendar.date(from: rhs.fireDate)
            else { return false }
            return lhsDate < rhsDate
        }
    }

    private static func dayMatches(rule: ReminderRule, date: Date, dayOffset: Int, calendar: Calendar) -> Bool {
        switch rule.repeatType {
        case .daily:
            return true
        case .weekly:
            let weekday = calendar.component(.weekday, from: date)
            return rule.daysOfWeek.contains { $0.calendarWeekday == weekday }
        case .interval:
            guard let interval = rule.intervalDays, interval > 0 else { return false }
            return dayOffset % interval == 0
        }
    }
}

private extension Weekday {
    var calendarWeekday: Int {
        switch self {
        case .sunday:    return 1
        case .monday:    return 2
        case .tuesday:   return 3
        case .wednesday: return 4
        case .thursday:  return 5
        case .friday:    return 6
        case .saturday:  return 7
        }
    }
}
