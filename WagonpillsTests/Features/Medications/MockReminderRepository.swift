import Foundation
@testable import Wagonpills

final class MockReminderRepository: ReminderRepository, @unchecked Sendable {
    var fetchRulesResult: Result<[ReminderRule], Error> = .success([])
    var createRuleResult: Result<ReminderRule, Error> = .failure(APIError.unexpected("not configured"))
    var updateRuleResult: Result<ReminderRule, Error> = .failure(APIError.unexpected("not configured"))
    var deleteRuleResult: Result<Void, Error> = .success(())
    var addTimeResult: Result<ReminderTime, Error> = .failure(APIError.unexpected("not configured"))
    var deleteTimeResult: Result<Void, Error> = .success(())

    private(set) var createRuleCallCount = 0
    private(set) var updateRuleCallCount = 0
    private(set) var deleteRuleCallCount = 0
    private(set) var addTimeCallCount = 0
    private(set) var deleteTimeCallCount = 0
    private(set) var lastDeletedRuleId: Int64?
    private(set) var lastDeletedTimeId: Int64?

    func fetchRules(medicationId: Int64) async throws -> [ReminderRule] {
        try fetchRulesResult.get()
    }

    func createRule(medicationId: Int64, _ request: ReminderRuleCreateRequest) async throws -> ReminderRule {
        createRuleCallCount += 1
        return try createRuleResult.get()
    }

    func updateRule(medicationId: Int64, ruleId: Int64, _ request: ReminderRuleUpdateRequest) async throws -> ReminderRule {
        updateRuleCallCount += 1
        return try updateRuleResult.get()
    }

    func deleteRule(medicationId: Int64, ruleId: Int64) async throws {
        deleteRuleCallCount += 1
        lastDeletedRuleId = ruleId
        try deleteRuleResult.get()
    }

    func addTime(medicationId: Int64, ruleId: Int64, time: DateComponents) async throws -> ReminderTime {
        addTimeCallCount += 1
        return try addTimeResult.get()
    }

    func deleteTime(medicationId: Int64, ruleId: Int64, timeId: Int64) async throws {
        deleteTimeCallCount += 1
        lastDeletedTimeId = timeId
        try deleteTimeResult.get()
    }

    static func makeTestRule(
        id: Int64 = 1,
        repeatType: RepeatType = .daily,
        times: [ReminderTime] = []
    ) -> ReminderRule {
        ReminderRule(
            id: id,
            repeatType: repeatType,
            intervalDays: nil,
            daysOfWeek: [],
            active: true,
            times: times
        )
    }

    static func makeTestTime(id: Int64 = 1, hour: Int = 8, minute: Int = 0) -> ReminderTime {
        ReminderTime(id: id, hour: hour, minute: minute)
    }
}
