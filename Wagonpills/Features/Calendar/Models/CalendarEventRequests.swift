import Foundation

struct CalendarEventCreateRequest: Sendable {
    var type: CalendarEventType
    var title: String
    var description: String?
    var location: String?
    var startsAt: Date
    var endsAt: Date?
    var timezone: String?
    var doctorVisitId: Int64?
}

extension CalendarEventCreateRequest {
    func toDTO() -> Components.Schemas.CreateCalendarEventRequest {
        Components.Schemas.CreateCalendarEventRequest(
            _type: .init(rawValue: type.rawValue) ?? .other,
            title: title,
            description: description,
            location: location,
            startsAt: startsAt,
            endsAt: endsAt,
            timezone: timezone,
            doctorVisitId: doctorVisitId
        )
    }
}

struct CalendarEventUpdateRequest: Sendable {
    var type: CalendarEventType?
    var title: String?
    var description: String?
    var location: String?
    var startsAt: Date?
    var endsAt: Date?
    var timezone: String?
    var isCancelled: Bool?
}

extension CalendarEventUpdateRequest {
    func toDTO() -> Components.Schemas.UpdateCalendarEventRequest {
        Components.Schemas.UpdateCalendarEventRequest(
            _type: type.flatMap { .init(rawValue: $0.rawValue) },
            title: title,
            description: description,
            location: location,
            startsAt: startsAt,
            endsAt: endsAt,
            timezone: timezone,
            cancelled: isCancelled
        )
    }
}

struct EventReminderCreateRequest: Sendable {
    var reminderType: EventReminderType
    var minutesBefore: Int?
    var reminderAt: Date?
    var channel: ReminderChannel
}

extension EventReminderCreateRequest {
    func toDTO() -> Components.Schemas.CreateEventReminderRequest {
        Components.Schemas.CreateEventReminderRequest(
            reminderType: .init(rawValue: reminderType.rawValue) ?? .beforeEvent,
            minutesBefore: minutesBefore.map { Int32($0) },
            reminderAt: reminderAt,
            channel: .init(rawValue: channel.rawValue) ?? .push
        )
    }
}
