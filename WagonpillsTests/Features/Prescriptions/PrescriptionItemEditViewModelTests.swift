import Foundation
import Testing
@testable import Wagonpills

@Suite("PrescriptionItemEditViewModel")
@MainActor
struct PrescriptionItemEditViewModelTests {

    // MARK: - Validation

    @Test("save() with empty medication name sets saveState to .failed(.validation)")
    func saveEmptyNameFails() async {
        let repo = MockPrescriptionRepository()
        let vm = PrescriptionItemEditViewModel(mode: .create(prescriptionId: 1), repository: repo)
        vm.medicationName = "   "

        await vm.save()

        guard case .failed(let error) = vm.saveState,
              case .validation = error else {
            Issue.record("Expected .failed(.validation), got \(vm.saveState)")
            return
        }
        #expect(repo.createItemCallCount == 0)
    }

    @Test("isSaveDisabled is true when medicationName is empty")
    func isSaveDisabledWhenNameEmpty() {
        let repo = MockPrescriptionRepository()
        let vm = PrescriptionItemEditViewModel(mode: .create(prescriptionId: 1), repository: repo)
        vm.medicationName = ""

        #expect(vm.isSaveDisabled == true)
    }

    @Test("isSaveDisabled is false when medicationName is non-empty")
    func isSaveEnabledWhenNameProvided() {
        let repo = MockPrescriptionRepository()
        let vm = PrescriptionItemEditViewModel(mode: .create(prescriptionId: 1), repository: repo)
        vm.medicationName = "Aspirin"

        #expect(vm.isSaveDisabled == false)
    }

    // MARK: - Create mode

    @Test("save() in create mode calls repository.createItem and sets saveState to .saved")
    func saveCreateSuccess() async {
        let repo = MockPrescriptionRepository()
        let item = MockPrescriptionRepository.makeTestItem()
        repo.createItemResult = .success(item)

        let vm = PrescriptionItemEditViewModel(mode: .create(prescriptionId: 1), repository: repo)
        vm.medicationName = "Amoxicillin"
        vm.dosageText = "500 mg"
        vm.durationDaysText = "7"

        await vm.save()

        #expect(repo.createItemCallCount == 1)
        #expect(vm.saveState == .saved)
    }

    @Test("save() in create mode with network failure sets saveState to .failed(.network)")
    func saveCreateNetworkFailure() async {
        let repo = MockPrescriptionRepository()
        repo.createItemResult = .failure(APIError.network)

        let vm = PrescriptionItemEditViewModel(mode: .create(prescriptionId: 1), repository: repo)
        vm.medicationName = "Aspirin"

        await vm.save()

        #expect(vm.saveState == .failed(.network))
    }

    // MARK: - Edit mode

    @Test("save() in edit mode calls repository.updateItem and sets saveState to .saved")
    func saveEditSuccess() async {
        let repo = MockPrescriptionRepository()
        let existing = MockPrescriptionRepository.makeTestItem(id: 5)
        let updated = MockPrescriptionRepository.makeTestItem(id: 5)
        repo.updateItemResult = .success(updated)

        let vm = PrescriptionItemEditViewModel(mode: .edit(existing), repository: repo)
        vm.medicationName = "Amoxicillin"

        await vm.save()

        #expect(repo.updateItemCallCount == 1)
        #expect(vm.saveState == .saved)
    }

    @Test("edit mode pre-populates fields from existing item")
    func editModePrePopulates() {
        let item = PrescriptionItem(
            id: 3,
            prescriptionId: 1,
            medicationName: "Ibuprofen",
            dosageText: "400 mg",
            instructions: "With food",
            durationDays: 5
        )
        let repo = MockPrescriptionRepository()
        let vm = PrescriptionItemEditViewModel(mode: .edit(item), repository: repo)

        #expect(vm.medicationName == "Ibuprofen")
        #expect(vm.dosageText == "400 mg")
        #expect(vm.instructions == "With food")
        #expect(vm.durationDaysText == "5")
    }
}
