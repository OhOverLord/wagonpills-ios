import Foundation

enum EventReminderType: String, Sendable, Codable {
    case beforeEvent = "BEFORE_EVENT"
    case exactTime = "EXACT_TIME"
}

enum ReminderChannel: String, Sendable, Codable {
    case push = "PUSH"
    case email = "EMAIL"
}

struct EventReminder: Identifiable, Equatable, Sendable, Codable {
    let id: Int64
    let eventId: Int64
    var reminderType: EventReminderType
    var minutesBefore: Int?
    var reminderAt: Date?
    var channel: ReminderChannel
    var isActive: Bool
}

// MARK: - DTO mapping

extension EventReminder {
    static func from(_ dto: Components.Schemas.EventReminderResponse) throws -> EventReminder {
        guard let reminderId = dto.id else { throw APIError.decoding }
        guard let eventId = dto.eventId else { throw APIError.decoding }
        guard let typePayload = dto.reminderType else { throw APIError.decoding }
        guard let channelPayload = dto.channel else { throw APIError.decoding }
        guard let reminderType = EventReminderType(rawValue: typePayload.rawValue) else {
            throw APIError.decoding
        }
        guard let channel = ReminderChannel(rawValue: channelPayload.rawValue) else {
            throw APIError.decoding
        }
        return EventReminder(
            id: reminderId,
            eventId: eventId,
            reminderType: reminderType,
            minutesBefore: dto.minutesBefore.map { Int($0) },
            reminderAt: dto.reminderAt,
            channel: channel,
            isActive: dto.active ?? false
        )
    }
}
