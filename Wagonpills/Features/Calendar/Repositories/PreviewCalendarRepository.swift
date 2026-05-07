#if DEBUG
import Foundation

struct PreviewCalendarRepository: CalendarRepository {
    var events: [CalendarEvent]
    var error: APIError?

    init(events: [CalendarEvent] = Self.sampleEvents, error: APIError? = nil) {
        self.events = events
        self.error = error
    }

    func fetchAll() async throws -> [CalendarEvent] {
        if let error { throw error }
        return events
    }

    func fetchById(_ id: Int64) async throws -> CalendarEvent {
        if let error { throw error }
        guard let found = events.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return found
    }

    func create(_ request: CalendarEventCreateRequest) async throws -> CalendarEvent {
        if let error { throw error }
        return CalendarEvent(
            id: Int64.random(in: 100...999),
            type: request.type,
            title: request.title,
            description: request.description,
            location: request.location,
            startsAt: request.startsAt,
            endsAt: request.endsAt,
            timezone: request.timezone,
            doctorVisitId: request.doctorVisitId,
            isCancelled: false,
            reminders: []
        )
    }

    func update(id: Int64, _ request: CalendarEventUpdateRequest) async throws -> CalendarEvent {
        if let error { throw error }
        guard let existing = events.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return CalendarEvent(
            id: existing.id,
            type: request.type ?? existing.type,
            title: request.title ?? existing.title,
            description: request.description ?? existing.description,
            location: request.location ?? existing.location,
            startsAt: request.startsAt ?? existing.startsAt,
            endsAt: request.endsAt ?? existing.endsAt,
            timezone: request.timezone ?? existing.timezone,
            doctorVisitId: existing.doctorVisitId,
            isCancelled: request.isCancelled ?? existing.isCancelled,
            reminders: existing.reminders
        )
    }

    func delete(id: Int64) async throws {
        if let error { throw error }
    }

    func fetchReminders(eventId: Int64) async throws -> [EventReminder] {
        if let error { throw error }
        return events.first(where: { $0.id == eventId })?.reminders ?? []
    }

    func createReminder(eventId: Int64, _ request: EventReminderCreateRequest) async throws -> EventReminder {
        if let error { throw error }
        return EventReminder(
            id: Int64.random(in: 100...999),
            eventId: eventId,
            reminderType: request.reminderType,
            minutesBefore: request.minutesBefore,
            reminderAt: request.reminderAt,
            channel: request.channel,
            isActive: true
        )
    }

    func deleteReminder(eventId: Int64, reminderId: Int64) async throws {
        if let error { throw error }
    }

    static let sampleEvents: [CalendarEvent] = {
        let cal = Calendar.current
        let now = Date()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        let nextWeek = cal.date(byAdding: .day, value: 7, to: now) ?? now
        return [
            CalendarEvent(
                id: 1,
                type: .doctorVisit,
                title: "Cardiology Check-up",
                description: "Annual heart examination",
                location: "Prague General Hospital",
                startsAt: tomorrow,
                endsAt: cal.date(byAdding: .hour, value: 1, to: tomorrow),
                timezone: "Europe/Prague",
                doctorVisitId: nil,
                isCancelled: false,
                reminders: [
                    EventReminder(
                        id: 1,
                        eventId: 1,
                        reminderType: .beforeEvent,
                        minutesBefore: 30,
                        reminderAt: nil,
                        channel: .push,
                        isActive: true
                    )
                ]
            ),
            CalendarEvent(
                id: 2,
                type: .medicationRefill,
                title: "Pharmacy Run",
                description: nil,
                location: "City Pharmacy",
                startsAt: nextWeek,
                endsAt: nil,
                timezone: "Europe/Prague",
                doctorVisitId: nil,
                isCancelled: false,
                reminders: []
            ),
            CalendarEvent(
                id: 3,
                type: .labTest,
                title: "Blood Test",
                description: "Fasting required",
                location: "City Lab Center",
                startsAt: cal.date(byAdding: .day, value: 3, to: now) ?? now,
                endsAt: nil,
                timezone: "Europe/Prague",
                doctorVisitId: nil,
                isCancelled: true,
                reminders: []
            )
        ]
    }()
}
#endif
