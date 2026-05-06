import Foundation
import Testing
@testable import Wagonpills

@Suite("PrescriptionEditViewModel")
@MainActor
struct PrescriptionEditViewModelTests {

    // MARK: - Create mode

    @Test("save() in create mode calls repository.create and sets saveState to .saved")
    func saveCreateSuccess() async {
        let repo = MockPrescriptionRepository()
        let prescription = MockPrescriptionRepository.makeTestPrescription(id: 42)
        repo.createResult = .success(prescription)

        let vm = PrescriptionEditViewModel(mode: .create, repository: repo)
        vm.note = "My prescription"

        await vm.save()

        #expect(repo.createCallCount == 1)
        #expect(vm.saveState == .saved)
    }

    @Test("save() in create mode with network failure sets saveState to .failed(.network)")
    func saveCreateNetworkFailure() async {
        let repo = MockPrescriptionRepository()
        repo.createResult = .failure(APIError.network)

        let vm = PrescriptionEditViewModel(mode: .create, repository: repo)
        await vm.save()

        #expect(vm.saveState == .failed(.network))
    }

    @Test("save() in create mode with 400 sets saveState to .failed(.validation)")
    func saveCreateValidationFailure() async {
        let repo = MockPrescriptionRepository()
        repo.createResult = .failure(APIError.validation(message: nil))

        let vm = PrescriptionEditViewModel(mode: .create, repository: repo)
        await vm.save()

        guard case .failed(let error) = vm.saveState,
              case .validation = error else {
            Issue.record("Expected .failed(.validation), got \(vm.saveState)")
            return
        }
        #expect(repo.createCallCount == 1)
    }

    // MARK: - Create mode with pending items

    @Test("save() in create mode creates prescription then all pending items")
    func saveCreateWithPendingItems() async {
        let repo = MockPrescriptionRepository()
        let prescription = MockPrescriptionRepository.makeTestPrescription(id: 10)
        repo.createResult = .success(prescription)
        repo.createItemResult = .success(MockPrescriptionRepository.makeTestItem(prescriptionId: 10))

        let vm = PrescriptionEditViewModel(mode: .create, repository: repo)
        vm.addDraftItem(.init(medicationName: "Aspirin", dosageText: "100 mg", instructions: nil, durationDays: nil))
        vm.addDraftItem(.init(medicationName: "Ibuprofen", dosageText: nil, instructions: nil, durationDays: 5))

        await vm.save()

        #expect(repo.createCallCount == 1)
        #expect(repo.createItemCallCount == 2)
        #expect(vm.saveState == .saved)
    }

    @Test("save() in create mode stops and fails if createItem fails")
    func saveCreateItemFailure() async {
        let repo = MockPrescriptionRepository()
        repo.createResult = .success(MockPrescriptionRepository.makeTestPrescription(id: 1))
        repo.createItemResult = .failure(APIError.network)

        let vm = PrescriptionEditViewModel(mode: .create, repository: repo)
        vm.addDraftItem(.init(medicationName: "Aspirin", dosageText: nil, instructions: nil, durationDays: nil))

        await vm.save()

        #expect(vm.saveState == .failed(.network))
    }

    @Test("removeDraftItems removes item at given offset")
    func removeDraftItem() {
        let repo = MockPrescriptionRepository()
        let vm = PrescriptionEditViewModel(mode: .create, repository: repo)
        vm.addDraftItem(.init(medicationName: "Aspirin", dosageText: nil, instructions: nil, durationDays: nil))
        vm.addDraftItem(.init(medicationName: "Ibuprofen", dosageText: nil, instructions: nil, durationDays: nil))

        vm.removeDraftItems(at: IndexSet(integer: 0))

        #expect(vm.pendingItems.count == 1)
        #expect(vm.pendingItems[0].medicationName == "Ibuprofen")
    }

    // MARK: - Edit mode

    @Test("save() in edit mode calls repository.update and sets saveState to .saved")
    func saveEditSuccess() async {
        let repo = MockPrescriptionRepository()
        let existing = MockPrescriptionRepository.makeTestPrescription(id: 7, note: "Old")
        let updated = MockPrescriptionRepository.makeTestPrescription(id: 7, note: "New")
        repo.updateResult = .success(updated)

        let vm = PrescriptionEditViewModel(mode: .edit(existing), repository: repo)
        vm.note = "New"

        await vm.save()

        #expect(repo.updateCallCount == 1)
        #expect(vm.saveState == .saved)
    }

    @Test("edit mode pre-populates fields from existing prescription")
    func editModePrePopulates() {
        let prescription = Prescription(
            id: 5,
            doctorVisitId: 3,
            issuedAt: Date(),
            note: "Take with food",
            createdAt: Date(),
            items: []
        )
        let repo = MockPrescriptionRepository()
        let vm = PrescriptionEditViewModel(mode: .edit(prescription), repository: repo)

        #expect(vm.doctorVisitId == 3)
        #expect(vm.note == "Take with food")
        #expect(vm.issuedAt != nil)
    }
}
