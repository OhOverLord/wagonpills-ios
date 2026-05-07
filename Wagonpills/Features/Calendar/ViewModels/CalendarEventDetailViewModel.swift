import Foundation
import Observation

@MainActor
@Observable
final class CalendarEventDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(CalendarEvent)
        case failed(APIError)
    }

    private(set) var state: State = .loading
    private(set) var isDeletingReminder = false

    let eventId: Int64
    let repository: any CalendarRepository
    let scheduler: any NotificationScheduler
    let visitRepository: (any VisitRepository)?

    init(
        eventId: Int64,
        repository: any CalendarRepository,
        scheduler: any NotificationScheduler,
        visitRepository: (any VisitRepository)? = nil
    ) {
        self.eventId = eventId
        self.repository = repository
        self.scheduler = scheduler
        self.visitRepository = visitRepository
    }

    func load() async {
        do {
            let event = try await repository.fetchById(eventId)
            state = .loaded(event)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }

    func deleteReminder(_ reminder: EventReminder) async {
        guard case .loaded(var event) = state else { return }
        isDeletingReminder = true
        do {
            try await repository.deleteReminder(eventId: eventId, reminderId: reminder.id)
            await scheduler.cancelEventReminder(id: reminder.id)
            event.reminders.removeAll { $0.id == reminder.id }
            state = .loaded(event)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
        isDeletingReminder = false
    }
}
