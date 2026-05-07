import Foundation
import Observation

@MainActor
@Observable
final class EventReminderEditViewModel {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(APIError)
        case permissionDenied
    }

    var reminderType: EventReminderType = .beforeEvent
    var minutesBefore: Int = 30
    var reminderAt: Date = .now

    private(set) var saveState: SaveState = .idle

    let eventId: Int64
    let repository: any CalendarRepository
    let scheduler: any NotificationScheduler

    init(eventId: Int64, repository: any CalendarRepository, scheduler: any NotificationScheduler) {
        self.eventId = eventId
        self.repository = repository
        self.scheduler = scheduler
    }

    func save(for event: CalendarEvent) async {
        saveState = .saving
        let request = EventReminderCreateRequest(
            reminderType: reminderType,
            minutesBefore: reminderType == .beforeEvent ? minutesBefore : nil,
            reminderAt: reminderType == .exactTime ? reminderAt : nil,
            channel: .push
        )
        do {
            let reminder = try await repository.createReminder(eventId: eventId, request)
            if reminder.channel == .push {
                do {
                    try await scheduler.scheduleEventReminder(reminder, for: event)
                } catch let scheduleError as APIError {
                    if case .unexpected = scheduleError {
                        saveState = .permissionDenied
                        return
                    }
                } catch {}
            }
            saveState = .saved
        } catch let error as APIError {
            saveState = .failed(error)
        } catch {
            saveState = .failed(APIError.from(error))
        }
    }
}
