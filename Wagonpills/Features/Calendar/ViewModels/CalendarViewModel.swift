import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([CalendarEvent])
        case failed(APIError)
    }

    private(set) var state: State = .idle
    var selectedDate: Date?
    var selectedMonth: Date

    let repository: any CalendarRepository
    let visitRepository: (any VisitRepository)?

    init(repository: any CalendarRepository, visitRepository: (any VisitRepository)? = nil) {
        self.repository = repository
        self.visitRepository = visitRepository
        self.selectedMonth = Calendar.current.startOfMonth(for: Date())
    }

    var eventsForSelectedDate: [CalendarEvent] {
        guard case .loaded(let events) = state, let date = selectedDate else { return [] }
        return events.filter { Calendar.current.isDate($0.startsAt, inSameDayAs: date) }
            .sorted { $0.startsAt < $1.startsAt }
    }

    var datesWithEvents: Set<Date> {
        guard case .loaded(let events) = state else { return [] }
        return Set(events.map { Calendar.current.startOfDay(for: $0.startsAt) })
    }

    func load() async {
        if state == .idle { state = .loading }
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    func delete(_ event: CalendarEvent) async {
        do {
            try await repository.delete(id: event.id)
            if case .loaded(var events) = state {
                events.removeAll { $0.id == event.id }
                state = events.isEmpty ? .loaded([]) : .loaded(events)
            }
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }

    func previousMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        selectedDate = nil
    }

    func nextMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        selectedDate = nil
    }

    private func fetch() async {
        do {
            let events = try await repository.fetchAll()
            state = .loaded(events)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
