import Foundation
import SwiftUI

enum CalendarEventType: String, CaseIterable, Sendable, Codable {
    case doctorVisit = "DOCTOR_VISIT"
    case medicationRefill = "MEDICATION_REFILL"
    case labTest = "LAB_TEST"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .doctorVisit: return String(localized: "Doctor Visit")
        case .medicationRefill: return String(localized: "Medication Refill")
        case .labTest: return String(localized: "Lab Test")
        case .other: return String(localized: "Other")
        }
    }

    var systemImage: String {
        switch self {
        case .doctorVisit: return "stethoscope"
        case .medicationRefill: return "pills"
        case .labTest: return "flask"
        case .other: return "calendar"
        }
    }

    var color: Color {
        switch self {
        case .doctorVisit: return .blue
        case .medicationRefill: return .green
        case .labTest: return .purple
        case .other: return .orange
        }
    }
}

struct CalendarEvent: Identifiable, Equatable, Sendable, Codable {
    let id: Int64
    var type: CalendarEventType
    var title: String
    var description: String?
    var location: String?
    var startsAt: Date
    var endsAt: Date?
    var timezone: String?
    var doctorVisitId: Int64?
    var isCancelled: Bool
    var reminders: [EventReminder]
}

// MARK: - DTO mapping

extension CalendarEvent {
    static func from(
        _ dto: Components.Schemas.CalendarEventResponse,
        reminders: [EventReminder] = []
    ) throws -> CalendarEvent {
        guard let eventId = dto.id else { throw APIError.decoding }
        guard let typePayload = dto._type else { throw APIError.decoding }
        guard let title = dto.title else { throw APIError.decoding }
        guard let startsAt = dto.startsAt else { throw APIError.decoding }
        guard let eventType = CalendarEventType(rawValue: typePayload.rawValue) else {
            throw APIError.decoding
        }
        return CalendarEvent(
            id: eventId,
            type: eventType,
            title: title,
            description: dto.description,
            location: dto.location,
            startsAt: startsAt,
            endsAt: dto.endsAt,
            timezone: dto.timezone,
            doctorVisitId: dto.doctorVisitId,
            isCancelled: dto.cancelled ?? false,
            reminders: reminders
        )
    }
}
