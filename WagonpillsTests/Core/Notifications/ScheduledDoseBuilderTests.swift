import Foundation
import Testing
@testable import Wagonpills

// Monday 2026-01-05 used as a fixed anchor throughout these tests.
private let monday20260105: Date = {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 1; comps.day = 5
    comps.hour = 0; comps.minute = 0; comps.second = 0
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return cal.date(from: comps) ?? Date(timeIntervalSince1970: 1_767_484_800)
}()

private let utcCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return cal
}()

private func makeTimes(_ specs: [(Int, Int)]) -> [ReminderTime] {
    specs.enumerated().map { idx, spec in
        ReminderTime(id: Int64(idx + 1), hour: spec.0, minute: spec.1)
    }
}

private func makeRule(
    id: Int64 = 1,
    repeatType: RepeatType,
    intervalDays: Int? = nil,
    daysOfWeek: Set<Weekday> = [],
    times: [ReminderTime]
) -> ReminderRule {
    ReminderRule(id: id, repeatType: repeatType, intervalDays: intervalDays,
                 daysOfWeek: daysOfWeek, active: true, times: times)
}

@Suite("ScheduledDoseBuilder")
struct ScheduledDoseBuilderTests {

    @Test("DAILY rule with 2 times and 3-day window returns 6 doses")
    func dailyTwoTimesThreeDays() {
        let rule = makeRule(repeatType: .daily, times: makeTimes([(8, 0), (20, 0)]))
        let doses = ScheduledDoseBuilder.build(
            medicationId: 1, medicationName: "Aspirin",
            rule: rule, from: monday20260105, days: 3,
            calendar: utcCalendar
        )
        #expect(doses.count == 6)
    }

    @Test("WEEKLY rule with Monday only and 7-day window starting on Monday returns 1 day × times")
    func weeklyMondayOnlySevenDays() {
        let times = makeTimes([(8, 0), (20, 0)])
        let rule = makeRule(repeatType: .weekly, daysOfWeek: [.monday], times: times)
        let doses = ScheduledDoseBuilder.build(
            medicationId: 1, medicationName: "Aspirin",
            rule: rule, from: monday20260105, days: 7,
            calendar: utcCalendar
        )
        #expect(doses.count == 2)
    }

    @Test("WEEKLY rule with Monday and Wednesday and 14-day window returns 4 days × times")
    func weeklyMonWed14Days() {
        let times = makeTimes([(8, 0), (20, 0)])
        let rule = makeRule(repeatType: .weekly, daysOfWeek: [.monday, .wednesday], times: times)
        let doses = ScheduledDoseBuilder.build(
            medicationId: 1, medicationName: "Aspirin",
            rule: rule, from: monday20260105, days: 14,
            calendar: utcCalendar
        )
        // 2 weeks × 2 days per week × 2 times = 8
        #expect(doses.count == 8)
    }

    @Test("INTERVAL every 2 days with 7-day window returns doses for days 0,2,4,6 × times")
    func intervalEvery2Days7DayWindow() {
        let times = makeTimes([(8, 0), (20, 0)])
        let rule = makeRule(repeatType: .interval, intervalDays: 2, times: times)
        let doses = ScheduledDoseBuilder.build(
            medicationId: 1, medicationName: "Aspirin",
            rule: rule, from: monday20260105, days: 7,
            calendar: utcCalendar
        )
        // Days 0, 2, 4, 6 → 4 days × 2 times = 8
        #expect(doses.count == 8)
    }

    @Test("Empty times returns empty array")
    func emptyTimesReturnsEmpty() {
        let rule = makeRule(repeatType: .daily, times: [])
        let doses = ScheduledDoseBuilder.build(
            medicationId: 1, medicationName: "Aspirin",
            rule: rule, from: monday20260105, days: 7,
            calendar: utcCalendar
        )
        #expect(doses.isEmpty)
    }

    @Test("0-day window returns empty array")
    func zeroDayWindowReturnsEmpty() {
        let rule = makeRule(repeatType: .daily, times: makeTimes([(8, 0)]))
        let doses = ScheduledDoseBuilder.build(
            medicationId: 1, medicationName: "Aspirin",
            rule: rule, from: monday20260105, days: 0,
            calendar: utcCalendar
        )
        #expect(doses.isEmpty)
    }

    @Test("Doses are sorted by fireDate ascending")
    func dosesSortedAscending() {
        // Two times in reverse order to verify sorting
        let times = makeTimes([(20, 0), (8, 0)])
        let rule = makeRule(repeatType: .daily, times: times)
        let doses = ScheduledDoseBuilder.build(
            medicationId: 1, medicationName: "Aspirin",
            rule: rule, from: monday20260105, days: 1,
            calendar: utcCalendar
        )
        #expect(doses.count == 2)
        #expect(doses[0].fireDate.hour == 8)
        #expect(doses[1].fireDate.hour == 20)
    }

    @Test("INTERVAL with nil intervalDays returns empty array")
    func intervalNilIntervalDays() {
        let rule = makeRule(repeatType: .interval, intervalDays: nil, times: makeTimes([(8, 0)]))
        let doses = ScheduledDoseBuilder.build(
            medicationId: 1, medicationName: "Aspirin",
            rule: rule, from: monday20260105, days: 7,
            calendar: utcCalendar
        )
        #expect(doses.isEmpty)
    }
}
