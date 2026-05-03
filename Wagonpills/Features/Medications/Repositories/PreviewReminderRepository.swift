#if DEBUG
import Foundation

struct PreviewReminderRepository: ReminderRepository {
    var rules: [ReminderRule]
    var error: APIError?

    init(rules: [ReminderRule] = [], error: APIError? = nil) {
        self.rules = rules
        self.error = error
    }

    func fetchRules(medicationId: Int64) async throws -> [ReminderRule] {
        if let error { throw error }
        return rules
    }

    func createRule(medicationId: Int64, _ request: ReminderRuleCreateRequest) async throws -> ReminderRule {
        if let error { throw error }
        return ReminderRule(
            id: Int64.random(in: 100...999),
            repeatType: request.repeatType,
            intervalDays: request.intervalDays,
            daysOfWeek: request.daysOfWeek,
            active: true,
            times: []
        )
    }

    func updateRule(medicationId: Int64, ruleId: Int64, _ request: ReminderRuleUpdateRequest) async throws -> ReminderRule {
        if let error { throw error }
        guard let existing = rules.first(where: { $0.id == ruleId }) else { throw APIError.notFound }
        return ReminderRule(
            id: existing.id,
            repeatType: request.repeatType,
            intervalDays: request.intervalDays,
            daysOfWeek: request.daysOfWeek,
            active: request.active,
            times: existing.times
        )
    }

    func deleteRule(medicationId: Int64, ruleId: Int64) async throws {
        if let error { throw error }
    }

    func addTime(medicationId: Int64, ruleId: Int64, time: DateComponents) async throws -> ReminderTime {
        if let error { throw error }
        return ReminderTime(id: Int64.random(in: 100...999), hour: time.hour ?? 0, minute: time.minute ?? 0)
    }

    func deleteTime(medicationId: Int64, ruleId: Int64, timeId: Int64) async throws {
        if let error { throw error }
    }

    static func makePreviewRules() -> [ReminderRule] {
        [
            ReminderRule(
                id: 1,
                repeatType: .daily,
                intervalDays: nil,
                daysOfWeek: [],
                active: true,
                times: [
                    ReminderTime(id: 1, hour: 8, minute: 0),
                    ReminderTime(id: 2, hour: 20, minute: 0)
                ]
            ),
            ReminderRule(
                id: 2,
                repeatType: .weekly,
                intervalDays: nil,
                daysOfWeek: [.monday, .wednesday, .friday],
                active: true,
                times: [ReminderTime(id: 3, hour: 9, minute: 30)]
            )
        ]
    }
}
#endif
