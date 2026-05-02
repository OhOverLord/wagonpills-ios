import Foundation
import Testing
@testable import Wagonpills

@Suite("MedicationListViewModel")
@MainActor
struct MedicationListViewModelTests {
    private func makeVM(
        fetchResult: Result<[Medication], Error> = .success([])
    ) -> (MedicationListViewModel, MockMedicationRepository) {
        let repo = MockMedicationRepository()
        repo.fetchAllResult = fetchResult
        return (MedicationListViewModel(repository: repo), repo)
    }

    @Test("initial load transitions idle → loading → loaded")
    func initialLoadHappyPath() async {
        let medications = [MockMedicationRepository.makeTestMedication()]
        let (vm, _) = makeVM(fetchResult: .success(medications))

        #expect(vm.state == .idle)
        await vm.load()
        #expect(vm.state == .loaded(medications))
    }

    @Test("initial load with empty result transitions to .empty")
    func initialLoadEmpty() async {
        let (vm, _) = makeVM(fetchResult: .success([]))
        await vm.load()
        #expect(vm.state == .empty)
    }

    @Test("initial load network error transitions to .failed(.network)")
    func initialLoadNetworkError() async {
        let (vm, _) = makeVM(fetchResult: .failure(APIError.network))
        await vm.load()
        #expect(vm.state == .failed(.network))
    }

    @Test("second load when already loaded does not show full spinner")
    func secondLoadKeepsCurrentState() async {
        let medications = [MockMedicationRepository.makeTestMedication()]
        let (vm, _) = makeVM(fetchResult: .success(medications))

        await vm.load()
        // Second call should not reset to .loading (state is already .loaded)
        let stateBeforeSecondLoad = vm.state
        #expect(stateBeforeSecondLoad == .loaded(medications))
        await vm.load()
        #expect(vm.state == .loaded(medications))
    }

    @Test("refresh after failure re-attempts and succeeds")
    func refreshAfterFailureSucceeds() async {
        let repo = MockMedicationRepository()
        repo.fetchAllResult = .failure(APIError.network)
        let vm = MedicationListViewModel(repository: repo)

        await vm.load()
        #expect(vm.state == .failed(.network))

        let medications = [MockMedicationRepository.makeTestMedication()]
        repo.fetchAllResult = .success(medications)
        await vm.refresh()
        #expect(vm.state == .loaded(medications))
    }
}
