import Foundation
import Testing
@testable import Wagonpills

@Suite("EventReminderEditViewModel")
@MainActor
struct EventReminderEditViewModelTests {
    private func makeRepo(reminderResult: Result<EventReminder, Error>) -> MockCalendarRepository {
        let repo = MockCalendarRepository()
        repo.createReminderResult = reminderResult
        return repo
    }

    private func makeScheduler(error: Error? = nil) -> MockNotificationScheduler {
        let scheduler = MockNotificationScheduler()
        scheduler.scheduleEventReminderError = error
        return scheduler
    }

    private func makeVM(
        repo: MockCalendarRepository,
        scheduler: MockNotificationScheduler
    ) -> EventReminderEditViewModel {
        EventReminderEditViewModel(eventId: 1, repository: repo, scheduler: scheduler)
    }

    private var testEvent: CalendarEvent { MockCalendarRepository.makeTestEvent() }

    @Test("PUSH reminder schedules local notification")
    func pushReminderSchedulesNotification() async {
        let reminder = MockCalendarRepository.makeTestReminder(channel: .push)
        let repo = makeRepo(reminderResult: .success(reminder))
        let scheduler = makeScheduler()
        let vm = makeVM(repo: repo, scheduler: scheduler)
        vm.reminderType = .beforeEvent
        vm.minutesBefore = 30

        await vm.save(for: testEvent)

        #expect(vm.saveState == .saved)
        #expect(repo.createReminderCallCount == 1)
        #expect(scheduler.scheduleEventReminderCallCount == 1)
        #expect(scheduler.lastScheduledReminder?.channel == .push)
    }

    @Test("EMAIL reminder does not call scheduler")
    func emailReminderDoesNotSchedule() async {
        let reminder = MockCalendarRepository.makeTestReminder(channel: .email)
        let repo = makeRepo(reminderResult: .success(reminder))
        let scheduler = makeScheduler()
        let vm = makeVM(repo: repo, scheduler: scheduler)
        vm.reminderType = .beforeEvent

        await vm.save(for: testEvent)

        #expect(repo.createReminderCallCount == 1)
        #expect(scheduler.scheduleEventReminderCallCount == 0)
        #expect(vm.saveState == .saved)
    }

    @Test("notification permission denied surfaces permissionDenied state without rollback")
    func permissionDeniedSurfaces() async {
        let reminder = MockCalendarRepository.makeTestReminder(channel: .push)
        let repo = makeRepo(reminderResult: .success(reminder))
        let scheduler = makeScheduler(error: APIError.unexpected("Notification permission denied"))
        let vm = makeVM(repo: repo, scheduler: scheduler)

        await vm.save(for: testEvent)

        #expect(vm.saveState == .permissionDenied)
        #expect(repo.createReminderCallCount == 1)
        #expect(scheduler.scheduleEventReminderCallCount == 1)
    }

    @Test("repository failure surfaces error state")
    func repositoryFailure() async {
        let repo = makeRepo(reminderResult: .failure(APIError.network))
        let scheduler = makeScheduler()
        let vm = makeVM(repo: repo, scheduler: scheduler)

        await vm.save(for: testEvent)

        #expect(vm.saveState == .failed(.network))
        #expect(scheduler.scheduleEventReminderCallCount == 0)
    }

    @Test("exactTime reminder sends reminderAt date")
    func exactTimeReminderSendsDate() async {
        let targetDate = Date(timeIntervalSinceNow: 7200)
        let reminder = MockCalendarRepository.makeTestReminder(channel: .push)
        let repo = makeRepo(reminderResult: .success(reminder))
        let scheduler = makeScheduler()
        let vm = makeVM(repo: repo, scheduler: scheduler)
        vm.reminderType = .exactTime
        vm.reminderAt = targetDate

        await vm.save(for: testEvent)

        #expect(repo.createReminderCallCount == 1)
        #expect(repo.lastCreatedReminderRequest?.reminderType == .exactTime)
        #expect(repo.lastCreatedReminderRequest?.minutesBefore == nil)
        #expect(repo.lastCreatedReminderRequest?.reminderAt == targetDate)
    }
}
