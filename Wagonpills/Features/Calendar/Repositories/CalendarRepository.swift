import Foundation
import OpenAPIRuntime

// MARK: - Repository protocol

protocol CalendarRepository: Sendable {
    func fetchAll() async throws -> [CalendarEvent]
    func fetchById(_ id: Int64) async throws -> CalendarEvent
    func create(_ request: CalendarEventCreateRequest) async throws -> CalendarEvent
    func update(id: Int64, _ request: CalendarEventUpdateRequest) async throws -> CalendarEvent
    func delete(id: Int64) async throws
    func fetchReminders(eventId: Int64) async throws -> [EventReminder]
    func createReminder(eventId: Int64, _ request: EventReminderCreateRequest) async throws -> EventReminder
    func deleteReminder(eventId: Int64, reminderId: Int64) async throws
}

// MARK: - Narrow client protocol

protocol CalendarClient: Sendable {
    func getCalendarEvents() async throws -> Operations.GetAll4.Output
    func createCalendarEvent(_ body: Components.Schemas.CreateCalendarEventRequest) async throws -> Operations.Create10.Output
    func getCalendarEvent(id: Int64) async throws -> Operations.GetById8.Output
    func updateCalendarEvent(id: Int64, _ body: Components.Schemas.UpdateCalendarEventRequest) async throws -> Operations.Update9.Output
    func deleteCalendarEvent(id: Int64) async throws -> Operations.Delete9.Output
    func getEventReminders(eventId: Int64) async throws -> Operations.GetByEvent.Output
    func createEventReminder(
        eventId: Int64,
        _ body: Components.Schemas.CreateEventReminderRequest
    ) async throws -> Operations.Create11.Output
    func deleteEventReminder(eventId: Int64, reminderId: Int64) async throws -> Operations.Delete10.Output
}

extension APIClient: CalendarClient {
    func getCalendarEvents() async throws -> Operations.GetAll4.Output {
        try await client.getAll4()
    }
    func createCalendarEvent(
        _ body: Components.Schemas.CreateCalendarEventRequest
    ) async throws -> Operations.Create10.Output {
        try await client.create10(body: .json(body))
    }
    func getCalendarEvent(id: Int64) async throws -> Operations.GetById8.Output {
        try await client.getById8(path: .init(id: id))
    }
    func updateCalendarEvent(
        id: Int64,
        _ body: Components.Schemas.UpdateCalendarEventRequest
    ) async throws -> Operations.Update9.Output {
        try await client.update9(path: .init(id: id), body: .json(body))
    }
    func deleteCalendarEvent(id: Int64) async throws -> Operations.Delete9.Output {
        try await client.delete9(path: .init(id: id))
    }
    func getEventReminders(eventId: Int64) async throws -> Operations.GetByEvent.Output {
        try await client.getByEvent(path: .init(eventId: eventId))
    }
    func createEventReminder(
        eventId: Int64,
        _ body: Components.Schemas.CreateEventReminderRequest
    ) async throws -> Operations.Create11.Output {
        try await client.create11(path: .init(eventId: eventId), body: .json(body))
    }
    func deleteEventReminder(eventId: Int64, reminderId: Int64) async throws -> Operations.Delete10.Output {
        try await client.delete10(path: .init(eventId: eventId, reminderId: reminderId))
    }
}

// MARK: - Live implementation

final class LiveCalendarRepository: CalendarRepository {
    private let apiClient: any CalendarClient
    private let decoder: JSONDecoder

    init(apiClient: any CalendarClient) {
        self.apiClient = apiClient
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .custom { codingDecoder in
            let container = try codingDecoder.singleValueContainer()
            let string = try container.decode(String.self)
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: string) { return date }
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: string) { return date }
            // Handle local datetimes without timezone designator (e.g. Spring Boot default)
            isoFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
            if let date = isoFormatter.date(from: string) { return date }
            isoFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        self.decoder = jsonDecoder
    }

    func fetchAll() async throws -> [CalendarEvent] {
        let output = try await apiClient.getCalendarEvents()
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 10_485_760)
            return try decodeEventList(from: data)
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func fetchById(_ id: Int64) async throws -> CalendarEvent {
        let reminders = try await fetchReminders(eventId: id)
        let output = try await apiClient.getCalendarEvent(id: id)
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            return try decodeEventSingle(from: data, reminders: reminders)
        case .undocumented(let status, _):
            if status == 404 { throw APIError.notFound }
            throw APIError.server(status: status)
        }
    }

    func create(_ request: CalendarEventCreateRequest) async throws -> CalendarEvent {
        let output = try await apiClient.createCalendarEvent(request.toDTO())
        switch output {
        case .created(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            return try decodeEventSingle(from: data)
        case .badRequest:
            throw APIError.validation(message: nil)
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func update(id: Int64, _ request: CalendarEventUpdateRequest) async throws -> CalendarEvent {
        let output = try await apiClient.updateCalendarEvent(id: id, request.toDTO())
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            let reminders = try await fetchReminders(eventId: id)
            return try decodeEventSingle(from: data, reminders: reminders)
        case .undocumented(let status, _):
            if status == 404 { throw APIError.notFound }
            throw APIError.server(status: status)
        }
    }

    func delete(id: Int64) async throws {
        let output = try await apiClient.deleteCalendarEvent(id: id)
        switch output {
        case .ok:
            break
        case .undocumented(204, _):
            break
        case .undocumented(let status, _):
            if status == 404 { throw APIError.notFound }
            throw APIError.server(status: status)
        }
    }

    func fetchReminders(eventId: Int64) async throws -> [EventReminder] {
        let output = try await apiClient.getEventReminders(eventId: eventId)
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 5_242_880)
            return try decodeReminderList(from: data)
        case .undocumented(let status, _):
            if status == 404 { throw APIError.notFound }
            throw APIError.server(status: status)
        }
    }

    func createReminder(eventId: Int64, _ request: EventReminderCreateRequest) async throws -> EventReminder {
        let output = try await apiClient.createEventReminder(eventId: eventId, request.toDTO())
        switch output {
        case .created(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            return try decodeReminderSingle(from: data)
        case .notFound:
            throw APIError.notFound
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func deleteReminder(eventId: Int64, reminderId: Int64) async throws {
        let output = try await apiClient.deleteEventReminder(eventId: eventId, reminderId: reminderId)
        switch output {
        case .ok:
            break
        case .undocumented(204, _):
            break
        case .undocumented(let status, _):
            if status == 404 { throw APIError.notFound }
            throw APIError.server(status: status)
        }
    }
}

// MARK: - Private decode helpers

private extension LiveCalendarRepository {
    func decodeEventList(from data: Data) throws -> [CalendarEvent] {
        do {
            let dtos = try decoder.decode([Components.Schemas.CalendarEventResponse].self, from: data)
            return try dtos.map { try CalendarEvent.from($0) }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decoding
        }
    }

    func decodeEventSingle(from data: Data, reminders: [EventReminder] = []) throws -> CalendarEvent {
        do {
            let dto = try decoder.decode(Components.Schemas.CalendarEventResponse.self, from: data)
            return try CalendarEvent.from(dto, reminders: reminders)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decoding
        }
    }

    func decodeReminderList(from data: Data) throws -> [EventReminder] {
        do {
            let dtos = try decoder.decode([Components.Schemas.EventReminderResponse].self, from: data)
            return try dtos.map { try EventReminder.from($0) }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decoding
        }
    }

    func decodeReminderSingle(from data: Data) throws -> EventReminder {
        do {
            let dto = try decoder.decode(Components.Schemas.EventReminderResponse.self, from: data)
            return try EventReminder.from(dto)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decoding
        }
    }
}
