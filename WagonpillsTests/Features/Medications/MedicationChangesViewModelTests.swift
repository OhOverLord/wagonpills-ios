import Foundation
import Testing
@testable import Wagonpills

@Suite("MedicationChangesViewModel")
@MainActor
struct MedicationChangesViewModelTests {
    private static func makeChange(
        id: Int64 = 1,
        changeType: MedicationChangeType = .dosageChange,
        changedAt: Date = Date()
    ) -> MedicationChange {
        MedicationChange(
            id: id,
            medicationId: 1,
            medicationName: "Aspirin",
            doctorVisitId: nil,
            changeType: changeType,
            oldValue: "500mg",
            newValue: "1000mg",
            reason: "Doctor advised",
            changedAt: changedAt
        )
    }

    @Test("load() transitions to .loaded with sorted changes")
    func loadTransitionsToLoaded() async {
        let repo = MockMedicationRepository()
        let now = Date()
        let older = Self.makeChange(id: 1, changedAt: now.addingTimeInterval(-86400))
        let newer = Self.makeChange(id: 2, changedAt: now)
        repo.fetchChangesResult = .success([older, newer])
        let vm = MedicationChangesViewModel(medicationId: 1, repository: repo)

        await vm.load()

        #expect(repo.fetchChangesCallCount == 1)
        if case .loaded(let changes) = vm.listState {
            #expect(changes.count == 2)
            #expect(changes[0].id == newer.id)
            #expect(changes[1].id == older.id)
        } else {
            Issue.record("Expected .loaded, got \(vm.listState)")
        }
    }

    @Test("load() transitions to .failed on network error")
    func loadTransitionsToFailed() async {
        let repo = MockMedicationRepository()
        repo.fetchChangesResult = .failure(APIError.server(status: 500))
        let vm = MedicationChangesViewModel(medicationId: 1, repository: repo)

        await vm.load()

        if case .failed(let error) = vm.listState {
            #expect(error == .server(status: 500))
        } else {
            Issue.record("Expected .failed, got \(vm.listState)")
        }
    }

    @Test("createChange() saves and reloads list")
    func createChangeSavesAndReloads() async {
        let repo = MockMedicationRepository()
        let change = Self.makeChange()
        let medication = MockMedicationRepository.makeTestMedication()
        repo.createChangeResult = .success(change)
        repo.fetchByIdResult = .success(medication)
        repo.updateResult = .success(medication)
        repo.fetchChangesResult = .success([change])
        let vm = MedicationChangesViewModel(medicationId: 1, repository: repo)

        await vm.createChange()

        #expect(repo.createChangeCallCount == 1)
        #expect(repo.fetchChangesCallCount == 1)
        if case .saved = vm.saveState {
            // expected
        } else {
            Issue.record("Expected .saved, got \(vm.saveState)")
        }
        if case .loaded(let changes) = vm.listState {
            #expect(changes.count == 1)
        } else {
            Issue.record("Expected .loaded after reload, got \(vm.listState)")
        }
    }

    @Test("createChange() transitions to .failed on error")
    func createChangeFailsOnError() async {
        let repo = MockMedicationRepository()
        repo.createChangeResult = .failure(APIError.server(status: 422))
        let vm = MedicationChangesViewModel(medicationId: 1, repository: repo)

        await vm.createChange()

        if case .failed(let error) = vm.saveState {
            #expect(error == .server(status: 422))
        } else {
            Issue.record("Expected .failed save state, got \(vm.saveState)")
        }
    }

    @Test("resetForm() resets all form fields and saveState")
    func resetFormClearsState() async {
        let repo = MockMedicationRepository()
        let vm = MedicationChangesViewModel(medicationId: 1, repository: repo)
        vm.changeType = .stop
        vm.oldValue = "something"
        vm.newValue = "else"
        vm.reason = "because"
        vm.doctorVisitId = 42

        vm.resetForm()

        #expect(vm.changeType == .dosageChange)
        #expect(vm.oldValue.isEmpty)
        #expect(vm.newValue.isEmpty)
        #expect(vm.reason.isEmpty)
        #expect(vm.doctorVisitId == nil)
        #expect(vm.saveState == .idle)
    }
}
