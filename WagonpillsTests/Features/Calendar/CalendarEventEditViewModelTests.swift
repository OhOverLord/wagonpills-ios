import Foundation
import Testing
@testable import Wagonpills

@Suite("CalendarEventEditViewModel")
@MainActor
struct CalendarEventEditViewModelTests {
    private let testEvent = MockCalendarRepository.makeTestEvent(id: 1, type: .doctorVisit)
    private let testVisit = MockVisitRepository.makeTestVisit(id: 42)

    private func makeCalendarRepo(result: Result<CalendarEvent, Error>? = nil) -> MockCalendarRepository {
        let repo = MockCalendarRepository()
        repo.createResult = result ?? .success(MockCalendarRepository.makeTestEvent())
        return repo
    }

    private func makeVisitRepo(result: Result<Visit, Error>? = nil) -> MockVisitRepository {
        let repo = MockVisitRepository()
        repo.createResult = result ?? .success(MockVisitRepository.makeTestVisit(id: 42))
        return repo
    }

    // MARK: - initialDate

    @Test("initialDate pre-fills startsAt in create mode")
    func initialDatePreFillsStartsAt() {
        let target = Date(timeIntervalSinceNow: 86_400)
        let vm = CalendarEventEditViewModel(
            mode: .create,
            repository: makeCalendarRepo(),
            initialDate: target
        )
        #expect(Calendar.current.isDate(vm.startsAt, inSameDayAs: target))
    }

    @Test("initialDate is ignored in edit mode")
    func initialDateIgnoredInEditMode() {
        let target = Date(timeIntervalSinceNow: 86_400)
        let vm = CalendarEventEditViewModel(
            mode: .edit(testEvent),
            repository: makeCalendarRepo(),
            initialDate: target
        )
        #expect(Calendar.current.isDate(vm.startsAt, inSameDayAs: testEvent.startsAt))
    }

    // MARK: - Validation

    @Test("empty title blocks save")
    func emptyTitleBlocksSave() async {
        let repo = makeCalendarRepo()
        let vm = CalendarEventEditViewModel(mode: .create, repository: repo)
        vm.title = ""

        await vm.save()

        #expect(vm.saveState == .idle)
        #expect(repo.createCallCount == 0)
    }

    @Test("whitespace-only title blocks save")
    func whitespaceOnlyTitleBlocksSave() async {
        let repo = makeCalendarRepo()
        let vm = CalendarEventEditViewModel(mode: .create, repository: repo)
        vm.title = "   "

        await vm.save()

        #expect(vm.saveState == .idle)
        #expect(repo.createCallCount == 0)
    }

    // MARK: - Create mode

    @Test("create non-doctorVisit event calls repository.create once, no visit created")
    func createOtherEventNoVisit() async {
        let calendarRepo = makeCalendarRepo()
        let visitRepo = makeVisitRepo()
        let vm = CalendarEventEditViewModel(
            mode: .create,
            repository: calendarRepo,
            visitRepository: visitRepo
        )
        vm.type = .other
        vm.title = "Lab Test"

        await vm.save()

        #expect(vm.saveState == .saved)
        #expect(calendarRepo.createCallCount == 1)
        #expect(visitRepo.createCallCount == 0)
        #expect(calendarRepo.lastCreatedRequest?.doctorVisitId == nil)
    }

    @Test("create doctorVisit event creates visit first, then event with doctorVisitId")
    func createDoctorVisitCreatesVisitAndEvent() async {
        let calendarRepo = makeCalendarRepo()
        let visitRepo = makeVisitRepo()
        let vm = CalendarEventEditViewModel(
            mode: .create,
            repository: calendarRepo,
            visitRepository: visitRepo
        )
        vm.type = .doctorVisit
        vm.title = "Cardiology"

        await vm.save()

        #expect(vm.saveState == .saved)
        #expect(visitRepo.createCallCount == 1)
        #expect(calendarRepo.createCallCount == 1)
        #expect(calendarRepo.lastCreatedRequest?.doctorVisitId == 42)
        #expect(calendarRepo.lastCreatedRequest?.type == .doctorVisit)
    }

    @Test("create doctorVisit without visitRepository creates event without doctorVisitId")
    func createDoctorVisitWithoutVisitRepo() async {
        let calendarRepo = makeCalendarRepo()
        let vm = CalendarEventEditViewModel(
            mode: .create,
            repository: calendarRepo,
            visitRepository: nil
        )
        vm.type = .doctorVisit
        vm.title = "Checkup"

        await vm.save()

        #expect(vm.saveState == .saved)
        #expect(calendarRepo.createCallCount == 1)
        #expect(calendarRepo.lastCreatedRequest?.doctorVisitId == nil)
    }

    @Test("create doctorVisit with doctorName passes it to visitRepository")
    func createDoctorVisitPassesDoctorName() async {
        let calendarRepo = makeCalendarRepo()
        let visitRepo = MockVisitRepository()
        visitRepo.createResult = .success(MockVisitRepository.makeTestVisit(id: 10))
        let vm = CalendarEventEditViewModel(
            mode: .create,
            repository: calendarRepo,
            visitRepository: visitRepo
        )
        vm.type = .doctorVisit
        vm.title = "Visit"
        vm.doctorName = "Dr. Smith"

        await vm.save()

        #expect(vm.saveState == .saved)
        #expect(visitRepo.createCallCount == 1)
    }

    @Test("calendar repository failure in create sets saveState to .failed")
    func createCalendarRepositoryFailure() async {
        let calendarRepo = makeCalendarRepo(result: .failure(APIError.network))
        let vm = CalendarEventEditViewModel(mode: .create, repository: calendarRepo)
        vm.title = "Event"

        await vm.save()

        #expect(vm.saveState == .failed(.network))
        #expect(calendarRepo.createCallCount == 1)
    }

    @Test("visit repository failure in doctorVisit create propagates as .failed")
    func createDoctorVisitVisitRepositoryFailure() async {
        let calendarRepo = makeCalendarRepo()
        let visitRepo = makeVisitRepo(result: .failure(APIError.network))
        let vm = CalendarEventEditViewModel(
            mode: .create,
            repository: calendarRepo,
            visitRepository: visitRepo
        )
        vm.type = .doctorVisit
        vm.title = "Checkup"

        await vm.save()

        #expect(vm.saveState == .failed(.network))
        #expect(visitRepo.createCallCount == 1)
        #expect(calendarRepo.createCallCount == 0)
    }

    // MARK: - Edit mode

    @Test("edit mode calls repository.update, not create")
    func editModeCallsUpdate() async {
        let repo = MockCalendarRepository()
        repo.updateResult = .success(testEvent)
        let vm = CalendarEventEditViewModel(mode: .edit(testEvent), repository: repo)
        vm.title = "Updated Title"

        await vm.save()

        #expect(vm.saveState == .saved)
        #expect(repo.createCallCount == 0)
    }

    @Test("edit mode does not create a visit even for doctorVisit type")
    func editModeDoesNotCreateVisit() async {
        let calendarRepo = MockCalendarRepository()
        calendarRepo.updateResult = .success(testEvent)
        let visitRepo = makeVisitRepo()
        let vm = CalendarEventEditViewModel(
            mode: .edit(testEvent),
            repository: calendarRepo,
            visitRepository: visitRepo
        )
        vm.title = "Updated"

        await vm.save()

        #expect(visitRepo.createCallCount == 0)
        #expect(vm.saveState == .saved)
    }

    @Test("edit mode repository failure sets saveState to .failed")
    func editModeRepositoryFailure() async {
        let repo = MockCalendarRepository()
        repo.updateResult = .failure(APIError.network)
        let vm = CalendarEventEditViewModel(mode: .edit(testEvent), repository: repo)
        vm.title = "Title"

        await vm.save()

        #expect(vm.saveState == .failed(.network))
    }

    // MARK: - Navigation title

    @Test("navigationTitle is 'New Event' in create mode")
    func navigationTitleCreate() {
        let vm = CalendarEventEditViewModel(mode: .create, repository: makeCalendarRepo())
        #expect(vm.navigationTitle == String(localized: "New Event"))
    }

    @Test("navigationTitle is 'Edit Event' in edit mode")
    func navigationTitleEdit() {
        let vm = CalendarEventEditViewModel(mode: .edit(testEvent), repository: makeCalendarRepo())
        #expect(vm.navigationTitle == String(localized: "Edit Event"))
    }
}
