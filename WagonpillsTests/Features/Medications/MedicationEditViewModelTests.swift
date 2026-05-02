import Foundation
import Testing
@testable import Wagonpills

@Suite("MedicationEditViewModel")
@MainActor
struct MedicationEditViewModelTests {

    // MARK: - save() in create mode

    @Test("save() in create mode calls repository.create and sets saveState to .saved")
    func saveCreateSuccess() async {
        let repo = MockMedicationRepository()
        let med = MockMedicationRepository.makeTestMedication(id: 42, name: "Aspirin")
        repo.createResult = .success(med)

        let vm = MedicationEditViewModel(mode: .create, repository: repo)
        vm.name = "Aspirin"

        await vm.save()

        #expect(repo.createCallCount == 1)
        #expect(vm.saveState == .saved)
    }

    @Test("save() with empty name sets saveState to .failed(.validation)")
    func saveEmptyNameFails() async {
        let repo = MockMedicationRepository()
        let vm = MedicationEditViewModel(mode: .create, repository: repo)
        vm.name = "   "

        await vm.save()

        guard case .failed(let error) = vm.saveState,
              case .validation = error else {
            Issue.record("Expected .failed(.validation), got \(vm.saveState)")
            return
        }
        #expect(repo.createCallCount == 0)
    }

    @Test("save() in create mode with network failure sets saveState to .failed(.network)")
    func saveCreateNetworkFailure() async {
        let repo = MockMedicationRepository()
        repo.createResult = .failure(APIError.network)

        let vm = MedicationEditViewModel(mode: .create, repository: repo)
        vm.name = "Aspirin"

        await vm.save()

        #expect(vm.saveState == .failed(.network))
    }

    // MARK: - save() in edit mode

    @Test("save() in edit mode calls repository.update and sets saveState to .saved")
    func saveEditSuccess() async {
        let repo = MockMedicationRepository()
        let existing = MockMedicationRepository.makeTestMedication(id: 7, name: "Old Name")
        let updated = MockMedicationRepository.makeTestMedication(id: 7, name: "New Name")
        repo.updateResult = .success(updated)

        let vm = MedicationEditViewModel(mode: .edit(existing), repository: repo)
        vm.name = "New Name"

        await vm.save()

        #expect(repo.updateCallCount == 1)
        #expect(vm.saveState == .saved)
    }

    // MARK: - delete()

    @Test("delete() success calls repository.delete and sets saveState to .saved")
    func deleteSuccess() async {
        let repo = MockMedicationRepository()
        repo.deleteResult = .success(())
        let med = MockMedicationRepository.makeTestMedication(id: 5)

        let vm = MedicationEditViewModel(mode: .edit(med), repository: repo)

        await vm.delete()

        #expect(repo.deleteCallCount == 1)
        #expect(repo.lastDeletedId == 5)
        #expect(vm.saveState == .saved)
        #expect(vm.deleteError == nil)
    }

    @Test("delete() 404 sets deleteError and does not set saveState to .saved")
    func deleteNotFound() async {
        let repo = MockMedicationRepository()
        repo.deleteResult = .failure(APIError.notFound)
        let med = MockMedicationRepository.makeTestMedication(id: 5)

        let vm = MedicationEditViewModel(mode: .edit(med), repository: repo)

        await vm.delete()

        #expect(vm.deleteError == .notFound)
        #expect(vm.saveState == .idle)
    }

    // MARK: - Pre-population in edit mode

    @Test("edit mode pre-populates fields from existing medication")
    func editModePrePopulates() {
        let med = Medication(
            id: 1, name: "Metformin", dosageText: "500 mg",
            instructions: "After meals",
            startDate: Date(), endDate: nil, isActive: true,
            stockUnit: .capsule, doseQuantity: 2.0, currentStock: nil,
            lowStockThreshold: 5.0, catalogItemId: nil, regionCode: nil,
            createdAt: Date(), updatedAt: Date()
        )
        let repo = MockMedicationRepository()
        let vm = MedicationEditViewModel(mode: .edit(med), repository: repo)

        #expect(vm.name == "Metformin")
        #expect(vm.dosageText == "500 mg")
        #expect(vm.instructions == "After meals")
        #expect(vm.stockUnit == .capsule)
        #expect(vm.doseQuantity == "2.0")
        #expect(vm.lowStockThreshold == "5.0")
        #expect(vm.hasEndDate == false)
    }
}
