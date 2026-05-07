import Foundation
@testable import Wagonpills

final class MockCalendarRepository: CalendarRepository, @unchecked Sendable {
    var fetchAllResult: Result<[CalendarEvent], Error> = .success([])
    var fetchByIdResult: Result<CalendarEvent, Error> = .failure(APIError.notFound)
    var createResult: Result<CalendarEvent, Error> = .failure(APIError.unexpected("not configured"))
    var updateResult: Result<CalendarEvent, Error> = .failure(APIError.unexpected("not configured"))
    var deleteResult: Result<Void, Error> = .success(())
    var fetchRemindersResult: Result<[EventReminder], Error> = .success([])
    var createReminderResult: Result<EventReminder, Error> = .failure(APIError.unexpected("not configured"))
    var deleteReminderResult: Result<Void, Error> = .success(())

    private(set) var createCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var createReminderCallCount = 0
    private(set) var deleteReminderCallCount = 0
    private(set) var lastCreatedRequest: CalendarEventCreateRequest?
    private(set) var lastCreatedReminderRequest: EventReminderCreateRequest?

    func fetchAll() async throws -> [CalendarEvent] { try fetchAllResult.get() }

    func fetchById(_ id: Int64) async throws -> CalendarEvent { try fetchByIdResult.get() }

    func create(_ request: CalendarEventCreateRequest) async throws -> CalendarEvent {
        createCallCount += 1
        lastCreatedRequest = request
        return try createResult.get()
    }

    func update(id: Int64, _ request: CalendarEventUpdateRequest) async throws -> CalendarEvent {
        try updateResult.get()
    }

    func delete(id: Int64) async throws {
        deleteCallCount += 1
        try deleteResult.get()
    }

    func fetchReminders(eventId: Int64) async throws -> [EventReminder] { try fetchRemindersResult.get() }

    func createReminder(eventId: Int64, _ request: EventReminderCreateRequest) async throws -> EventReminder {
        createReminderCallCount += 1
        lastCreatedReminderRequest = request
        return try createReminderResult.get()
    }

    func deleteReminder(eventId: Int64, reminderId: Int64) async throws {
        deleteReminderCallCount += 1
        try deleteReminderResult.get()
    }

    static func makeTestEvent(id: Int64 = 1, type: CalendarEventType = .other) -> CalendarEvent {
        CalendarEvent(
            id: id,
            type: type,
            title: "Test Event",
            description: nil,
            location: nil,
            startsAt: Date(timeIntervalSinceNow: 3600),
            endsAt: nil,
            timezone: "Europe/Prague",
            doctorVisitId: nil,
            isCancelled: false,
            reminders: []
        )
    }

    static func makeTestReminder(id: Int64 = 1, eventId: Int64 = 1, channel: ReminderChannel = .push) -> EventReminder {
        EventReminder(
            id: id,
            eventId: eventId,
            reminderType: .beforeEvent,
            minutesBefore: 30,
            reminderAt: nil,
            channel: channel,
            isActive: true
        )
    }
}
