import Foundation
import Testing
@testable import Wagonpills

@Suite("ReminderMapping")
struct ReminderMappingTests {

    // MARK: - ReminderTime

    @Test("happy path — parses HH:mm:ss timeOfDay correctly")
    func timeHappyPath() throws {
        let dto = Components.Schemas.ReminderTimeResponse(id: 1, ruleId: 10, timeOfDay: "08:30:00")
        let time = try ReminderTime.from(dto)
        #expect(time.id == 1)
        #expect(time.hour == 8)
        #expect(time.minute == 30)
        #expect(time.displayString == "08:30")
    }

    @Test("parses HH:mm timeOfDay (no seconds) correctly")
    func timeWithoutSeconds() throws {
        let dto = Components.Schemas.ReminderTimeResponse(id: 2, ruleId: 10, timeOfDay: "14:05")
        let time = try ReminderTime.from(dto)
        #expect(time.hour == 14)
        #expect(time.minute == 5)
    }

    @Test("nil timeOfDay throws .decoding")
    func timeNilField() {
        let dto = Components.Schemas.ReminderTimeResponse(id: 1, ruleId: 10, timeOfDay: nil)
        #expect(throws: APIError.decoding) { try ReminderTime.from(dto) }
    }

    @Test("malformed timeOfDay string throws .decoding")
    func timeMalformedString() {
        let dto = Components.Schemas.ReminderTimeResponse(id: 1, ruleId: 10, timeOfDay: "not-a-time")
        #expect(throws: APIError.decoding) { try ReminderTime.from(dto) }
    }

    @Test("nil id throws .decoding")
    func timeNilId() {
        let dto = Components.Schemas.ReminderTimeResponse(id: nil, ruleId: 10, timeOfDay: "08:00:00")
        #expect(throws: APIError.decoding) { try ReminderTime.from(dto) }
    }

    // MARK: - ReminderRule

    @Test("happy path — DAILY rule maps correctly")
    func ruleDailyHappyPath() throws {
        let dto = Components.Schemas.ReminderRuleResponse(
            id: 1, medicationId: 42,
            repeatType: .daily,
            timezone: "Europe/Prague",
            intervalDays: nil,
            daysOfWeek: nil,
            active: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        let rule = try ReminderRule.from(dto, times: [])
        #expect(rule.id == 1)
        #expect(rule.repeatType == .daily)
        #expect(rule.daysOfWeek.isEmpty)
        #expect(rule.intervalDays == nil)
        #expect(rule.active == true)
    }

    @Test("WEEKLY rule parses daysOfWeek comma-separated string")
    func ruleWeeklyDays() throws {
        let dto = Components.Schemas.ReminderRuleResponse(
            id: 2, medicationId: 42,
            repeatType: .weekly,
            timezone: nil,
            intervalDays: nil,
            daysOfWeek: "MON,WED,FRI",
            active: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        let rule = try ReminderRule.from(dto, times: [])
        #expect(rule.repeatType == .weekly)
        #expect(rule.daysOfWeek == [.monday, .wednesday, .friday])
    }

    @Test("INTERVAL rule parses intervalDays")
    func ruleInterval() throws {
        let dto = Components.Schemas.ReminderRuleResponse(
            id: 3, medicationId: 42,
            repeatType: .interval,
            timezone: nil,
            intervalDays: 3,
            daysOfWeek: nil,
            active: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        let rule = try ReminderRule.from(dto, times: [])
        #expect(rule.repeatType == .interval)
        #expect(rule.intervalDays == 3)
        #expect(rule.active == false)
    }

    @Test("unknown weekday in daysOfWeek throws .decoding")
    func ruleUnknownWeekday() {
        let dto = Components.Schemas.ReminderRuleResponse(
            id: 4, medicationId: 42,
            repeatType: .weekly,
            timezone: nil,
            intervalDays: nil,
            daysOfWeek: "MON,INVALID,FRI",
            active: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        #expect(throws: APIError.decoding) { try ReminderRule.from(dto, times: []) }
    }

    @Test("nil id throws .decoding")
    func ruleNilId() {
        let dto = Components.Schemas.ReminderRuleResponse(
            id: nil, medicationId: 42,
            repeatType: .daily,
            timezone: nil, intervalDays: nil, daysOfWeek: nil,
            active: true, createdAt: Date(), updatedAt: Date()
        )
        #expect(throws: APIError.decoding) { try ReminderRule.from(dto, times: []) }
    }

    @Test("nil active throws .decoding")
    func ruleNilActive() {
        let dto = Components.Schemas.ReminderRuleResponse(
            id: 5, medicationId: 42,
            repeatType: .daily,
            timezone: nil, intervalDays: nil, daysOfWeek: nil,
            active: nil, createdAt: Date(), updatedAt: Date()
        )
        #expect(throws: APIError.decoding) { try ReminderRule.from(dto, times: []) }
    }

    @Test("embedded times are preserved in domain model")
    func ruleEmbedsTimes() throws {
        let dto = Components.Schemas.ReminderRuleResponse(
            id: 6, medicationId: 42,
            repeatType: .daily,
            timezone: nil, intervalDays: nil, daysOfWeek: nil,
            active: true, createdAt: Date(), updatedAt: Date()
        )
        let times = [ReminderTime(id: 1, hour: 8, minute: 0), ReminderTime(id: 2, hour: 20, minute: 0)]
        let rule = try ReminderRule.from(dto, times: times)
        #expect(rule.times.count == 2)
        #expect(rule.times[0].displayString == "08:00")
    }
}
