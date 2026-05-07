import Foundation
@testable import Wagonpills

final class MockNotificationScheduler: NotificationScheduler, @unchecked Sendable {
    private(set) var scheduleEventReminderCallCount = 0
    private(set) var cancelEventReminderCallCount = 0
    private(set) var lastScheduledReminder: EventReminder?
    private(set) var lastScheduledEvent: CalendarEvent?
    private(set) var lastCancelledReminderId: Int64?

    var scheduleEventReminderError: Error?

    func requestPermission() async -> Bool { true }
    func schedule(doses: [ScheduledDose]) async {}
    func cancelAll(medicationId: Int64) async {}
    func cancelAll() {}

    func scheduleEventReminder(_ reminder: EventReminder, for event: CalendarEvent) async throws {
        scheduleEventReminderCallCount += 1
        lastScheduledReminder = reminder
        lastScheduledEvent = event
        if let error = scheduleEventReminderError { throw error }
    }

    func cancelEventReminder(id: Int64) async {
        cancelEventReminderCallCount += 1
        lastCancelledReminderId = id
    }
}
