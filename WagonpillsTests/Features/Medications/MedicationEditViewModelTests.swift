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

        let vm = MedicationEditViewModel(mode: .create, repository: repo, catalogRepository: MockCatalogRepository())
        vm.name = "Aspirin"

        await vm.save()

        #expect(repo.createCallCount == 1)
        #expect(vm.saveState == .saved)
    }

    @Test("save() with empty name sets saveState to .failed(.validation)")
    func saveEmptyNameFails() async {
        let repo = MockMedicationRepository()
        let vm = MedicationEditViewModel(mode: .create, repository: repo, catalogRepository: MockCatalogRepository())
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

        let vm = MedicationEditViewModel(mode: .create, repository: repo, catalogRepository: MockCatalogRepository())
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

        let vm = MedicationEditViewModel(mode: .edit(existing), repository: repo, catalogRepository: MockCatalogRepository())
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

        let vm = MedicationEditViewModel(mode: .edit(med), repository: repo, catalogRepository: MockCatalogRepository())

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

        let vm = MedicationEditViewModel(mode: .edit(med), repository: repo, catalogRepository: MockCatalogRepository())

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
        let vm = MedicationEditViewModel(mode: .edit(med), repository: repo, catalogRepository: MockCatalogRepository())

        #expect(vm.name == "Metformin")
        #expect(vm.dosageText == "500 mg")
        #expect(vm.instructions == "After meals")
        #expect(vm.stockUnit == .capsule)
        #expect(vm.doseQuantity == "2.0")
        #expect(vm.lowStockThreshold == "5.0")
        #expect(vm.hasEndDate == false)
    }

    // MARK: - Catalog suggestions

    @Test("typing 3 chars triggers catalog search and shows inline suggestions")
    func suggestionsShowAfterTyping() async throws {
        let item = MockCatalogRepository.makeTestItem(id: 1, name: "Aspirin")
        let catalogRepo = MockCatalogRepository()
        catalogRepo.searchResult = .success([item])
        let vm = MedicationEditViewModel(mode: .create, repository: MockMedicationRepository(), catalogRepository: catalogRepo)

        vm.name = "Asp"

        try await Task.sleep(for: .milliseconds(350))

        #expect(vm.suggestions.isVisible == true)
        #expect(vm.suggestions.suggestions.count == 1)
        #expect(vm.suggestions.suggestions.first?.name == "Aspirin")
    }

    @Test("selecting a suggestion pre-fills name and dosageText and hides suggestions")
    func selectSuggestionPrefillsAndHides() async throws {
        let item = MockCatalogRepository.makeTestItem(id: 1, name: "Aspirin")
        let catalogRepo = MockCatalogRepository()
        catalogRepo.searchResult = .success([item])
        let vm = MedicationEditViewModel(mode: .create, repository: MockMedicationRepository(), catalogRepository: catalogRepo)

        vm.name = "Asp"
        try await Task.sleep(for: .milliseconds(350))

        let selected = vm.suggestions.select(item)
        vm.prefillFromCatalog(selected)

        #expect(vm.name == "Aspirin")
        #expect(vm.dosageText == "500 mg")
        #expect(vm.suggestions.isVisible == false)
    }

    @Test("re-selecting from catalog overwrites previous dosage")
    func reselectOverwritesDosage() async throws {
        let first = MockCatalogRepository.makeTestItem(id: 1, name: "Aspirin")
        let second = CatalogItem(id: 2, name: "Ibuprofen", strength: "200 mg", form: "tablet", regionCode: "CZ", aliases: [])
        let catalogRepo = MockCatalogRepository()
        catalogRepo.searchResult = .success([first])
        let vm = MedicationEditViewModel(mode: .create, repository: MockMedicationRepository(), catalogRepository: catalogRepo)

        vm.prefillFromCatalog(vm.suggestions.select(first))
        #expect(vm.dosageText == "500 mg")

        catalogRepo.searchResult = .success([second])
        vm.prefillFromCatalog(vm.suggestions.select(second))
        #expect(vm.name == "Ibuprofen")
        #expect(vm.dosageText == "200 mg")
    }
}
