import Foundation
import Testing
@testable import Wagonpills

@Suite("VisitEditViewModel")
@MainActor
struct VisitEditViewModelTests {

    @Test("save() in create mode calls repository.create and sets saveState to .saved")
    func saveCreateSuccess() async {
        let repo = MockVisitRepository()
        repo.createResult = .success(MockVisitRepository.makeTestVisit(id: 42))

        let vm = VisitEditViewModel(mode: .create, repository: repo)

        await vm.save()

        #expect(repo.createCallCount == 1)
        #expect(vm.saveState == .saved)
    }

    @Test("save() in create mode with 400 sets saveState to .failed(.validation)")
    func saveCreateValidationFailure() async {
        let repo = MockVisitRepository()
        repo.createResult = .failure(APIError.validation(message: nil))

        let vm = VisitEditViewModel(mode: .create, repository: repo)

        await vm.save()

        guard case .failed(let error) = vm.saveState, case .validation = error else {
            Issue.record("Expected .failed(.validation), got \(vm.saveState)")
            return
        }
    }

    @Test("save() in edit mode calls repository.update and sets saveState to .saved")
    func saveEditSuccess() async {
        let repo = MockVisitRepository()
        let existing = MockVisitRepository.makeTestVisit(id: 7)
        let updated = MockVisitRepository.makeTestVisit(id: 7, doctorName: "Dr. Updated")
        repo.updateResult = .success(updated)

        let vm = VisitEditViewModel(mode: .edit(existing), repository: repo)
        vm.doctorName = "Dr. Updated"

        await vm.save()

        #expect(repo.updateCallCount == 1)
        #expect(vm.saveState == .saved)
    }

    @Test("edit mode pre-populates fields from existing visit")
    func editModePrePopulates() {
        let visit = MockVisitRepository.makeTestVisit(id: 1, doctorName: "Dr. Smith")
        let repo = MockVisitRepository()
        let vm = VisitEditViewModel(mode: .edit(visit), repository: repo)

        #expect(vm.doctorName == "Dr. Smith")
        #expect(vm.specialty == "Cardiology")
        #expect(vm.location == "City Hospital")
    }

    @Test("save() network failure sets saveState to .failed(.network)")
    func saveNetworkFailure() async {
        let repo = MockVisitRepository()
        repo.createResult = .failure(APIError.network)

        let vm = VisitEditViewModel(mode: .create, repository: repo)

        await vm.save()

        #expect(vm.saveState == .failed(.network))
    }

    @Test("save() in create mode with generic Error sets saveState to .failed(.unexpected)")
    func saveCreateGenericError() async {
        struct GenericError: Error {}
        let repo = MockVisitRepository()
        repo.createResult = .failure(GenericError())

        let vm = VisitEditViewModel(mode: .create, repository: repo)
        await vm.save()

        guard case .failed(let error) = vm.saveState, case .unexpected = error else {
            Issue.record("Expected .failed(.unexpected), got \(vm.saveState)")
            return
        }
    }

    @Test("save() in edit mode with network failure sets saveState to .failed(.network)")
    func saveEditNetworkFailure() async {
        let repo = MockVisitRepository()
        repo.updateResult = .failure(APIError.network)

        let existing = MockVisitRepository.makeTestVisit(id: 3)
        let vm = VisitEditViewModel(mode: .edit(existing), repository: repo)
        await vm.save()

        #expect(vm.saveState == .failed(.network))
    }
}
