import Foundation
import Testing
@testable import Wagonpills

@Suite("StockUpdateViewModel")
@MainActor
struct StockUpdateViewModelTests {

    // MARK: - Validation

    @Test("save() with empty quantityText sets saveState to .failed(.validation)")
    func saveEmptyQuantity() async {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.quantityText = ""

        await vm.save()

        guard case .failed(let error) = vm.saveState, case .validation = error else {
            Issue.record("Expected .failed(.validation), got \(vm.saveState)")
            return
        }
    }

    @Test("save() with non-numeric quantityText sets saveState to .failed(.validation)")
    func saveNonNumericQuantity() async {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.quantityText = "abc"

        await vm.save()

        guard case .failed(let error) = vm.saveState, case .validation = error else {
            Issue.record("Expected .failed(.validation), got \(vm.saveState)")
            return
        }
    }

    @Test("save() with zero quantity sets saveState to .failed(.validation)")
    func saveZeroQuantity() async {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.quantityText = "0"

        await vm.save()

        guard case .failed(let error) = vm.saveState, case .validation = error else {
            Issue.record("Expected .failed(.validation), got \(vm.saveState)")
            return
        }
    }

    @Test("save() with .add operation and negative quantity sets saveState to .failed(.validation)")
    func saveAddNegativeQuantity() async {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.operation = .add
        vm.quantityText = "-5"

        await vm.save()

        guard case .failed(let error) = vm.saveState, case .validation = error else {
            Issue.record("Expected .failed(.validation), got \(vm.saveState)")
            return
        }
    }

    // MARK: - Add operation

    @Test("save() with .add operation success sets saveState to .saved")
    func saveAddSuccess() async {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.operation = .add
        vm.quantityText = "10"

        await vm.save()

        #expect(vm.saveState == .saved)
    }

    @Test("save() with .add passes note to repository when non-empty")
    func saveAddWithNote() async {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.operation = .add
        vm.quantityText = "5"
        vm.note = "Bought at pharmacy"

        await vm.save()

        #expect(vm.saveState == .saved)
    }

    @Test("save() with .add and empty note passes nil to repository")
    func saveAddEmptyNoteIsNil() async {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.operation = .add
        vm.quantityText = "5"
        vm.note = ""

        await vm.save()

        #expect(vm.saveState == .saved)
    }

    // MARK: - Adjust operation

    @Test("save() with .adjust operation and positive quantity sets saveState to .saved")
    func saveAdjustPositive() async {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.operation = .adjust
        vm.quantityText = "3"

        await vm.save()

        #expect(vm.saveState == .saved)
    }

    @Test("save() with .adjust operation and negative quantity sets saveState to .saved")
    func saveAdjustNegative() async {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.operation = .adjust
        vm.quantityText = "-3"

        await vm.save()

        #expect(vm.saveState == .saved)
    }

    // MARK: - Error propagation

    @Test("save() with .add and repository error sets saveState to .failed")
    func saveAddRepositoryError() async {
        let repo = MockMedicationRepository()
        repo.addStockResult = .failure(APIError.network)

        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.operation = .add
        vm.quantityText = "5"

        await vm.save()

        #expect(vm.saveState == .failed(.network))
    }

    @Test("save() with .adjust and repository error sets saveState to .failed")
    func saveAdjustRepositoryError() async {
        let repo = MockMedicationRepository()
        repo.adjustStockResult = .failure(APIError.server(status: 503))

        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)
        vm.operation = .adjust
        vm.quantityText = "2"

        await vm.save()

        guard case .failed(let error) = vm.saveState, case .server = error else {
            Issue.record("Expected .failed(.server), got \(vm.saveState)")
            return
        }
    }

    @Test("initial saveState is .idle")
    func initialStateIsIdle() {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)

        #expect(vm.saveState == .idle)
    }

    @Test("initial operation is .add")
    func initialOperationIsAdd() {
        let repo = MockMedicationRepository()
        let vm = StockUpdateViewModel(medicationId: 1, repository: repo)

        if case .add = vm.operation {
        } else {
            Issue.record("Expected .add operation by default")
        }
    }
}
