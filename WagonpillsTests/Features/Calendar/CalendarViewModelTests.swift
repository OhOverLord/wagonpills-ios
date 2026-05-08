import Foundation
import Testing
@testable import Wagonpills

@Suite("CalendarViewModel")
@MainActor
struct CalendarViewModelTests {
    private func makeVM(
        events: [CalendarEvent] = [],
        error: APIError? = nil
    ) -> (CalendarViewModel, MockCalendarRepository) {
        let repo = MockCalendarRepository()
        repo.fetchAllResult = error.map { .failure($0) } ?? .success(events)
        return (CalendarViewModel(repository: repo), repo)
    }

    @Test("initial load transitions idle → loaded")
    func initialLoadHappyPath() async {
        let event = MockCalendarRepository.makeTestEvent()
        let (vm, _) = makeVM(events: [event])

        #expect(vm.state == .idle)
        await vm.load()
        #expect(vm.state == .loaded([event]))
    }

    @Test("initial load with empty result stays loaded with empty array")
    func initialLoadEmpty() async {
        let (vm, _) = makeVM(events: [])
        await vm.load()
        #expect(vm.state == .loaded([]))
    }

    @Test("initial load network error transitions to .failed(.network)")
    func initialLoadNetworkError() async {
        let (vm, _) = makeVM(error: .network)
        await vm.load()
        #expect(vm.state == .failed(.network))
    }

    @Test("eventsForSelectedDate returns only events for that day")
    func eventsForSelectedDate() async {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now

        let todayEvent = CalendarEvent(
            id: 1, type: .other, title: "Today Event", description: nil, location: nil,
            startsAt: today.addingTimeInterval(3600), endsAt: nil, timezone: nil,
            doctorVisitId: nil, isCancelled: false, reminders: []
        )
        let tomorrowEvent = CalendarEvent(
            id: 2, type: .doctorVisit, title: "Tomorrow Event", description: nil, location: nil,
            startsAt: tomorrow, endsAt: nil, timezone: nil,
            doctorVisitId: nil, isCancelled: false, reminders: []
        )

        let (vm, _) = makeVM(events: [todayEvent, tomorrowEvent])
        await vm.load()

        vm.selectedDate = today
        let todayEvents = vm.eventsForSelectedDate
        #expect(todayEvents.count == 1)
        #expect(todayEvents.first?.id == 1)
    }

    @Test("delete removes event from loaded state")
    func deleteRemovesEvent() async {
        let event = MockCalendarRepository.makeTestEvent(id: 1)
        let (vm, repo) = makeVM(events: [event])
        repo.deleteResult = .success(())
        await vm.load()

        await vm.delete(event)
        #expect(vm.state == .loaded([]))
        #expect(repo.deleteCallCount == 1)
    }

    @Test("delete failure keeps loaded state and sets deleteError")
    func deleteFailure() async {
        let event = MockCalendarRepository.makeTestEvent(id: 1)
        let (vm, repo) = makeVM(events: [event])
        repo.deleteResult = .failure(APIError.network)
        await vm.load()

        await vm.delete(event)
        #expect(vm.state == .loaded([event]))
        #expect(vm.deleteError == .network)
    }

    @Test("previousMonth navigates back one month")
    func previousMonth() async {
        let (vm, _) = makeVM()
        let initial = vm.selectedMonth
        vm.previousMonth()
        let expected = Calendar.current.date(byAdding: .month, value: -1, to: initial) ?? initial
        #expect(Calendar.current.isDate(vm.selectedMonth, equalTo: expected, toGranularity: .month))
    }

    @Test("nextMonth navigates forward one month")
    func nextMonth() async {
        let (vm, _) = makeVM()
        let initial = vm.selectedMonth
        vm.nextMonth()
        let expected = Calendar.current.date(byAdding: .month, value: 1, to: initial) ?? initial
        #expect(Calendar.current.isDate(vm.selectedMonth, equalTo: expected, toGranularity: .month))
    }
}
