import Foundation
import Testing
@testable import Wagonpills

@Suite("PrescriptionListViewModel")
@MainActor
struct PrescriptionListViewModelTests {
    private func makeVM(
        fetchResult: Result<[Prescription], Error> = .success([]),
        visits: [Visit] = []
    ) -> (PrescriptionListViewModel, MockPrescriptionRepository) {
        let repo = MockPrescriptionRepository()
        repo.fetchAllResult = fetchResult
        let visitRepo = MockVisitRepository()
        visitRepo.fetchAllResult = .success(visits)
        return (PrescriptionListViewModel(repository: repo, visitRepository: visitRepo), repo)
    }

    @Test("initial load transitions idle → loading → loaded")
    func initialLoadHappyPath() async {
        let prescriptions = [MockPrescriptionRepository.makeTestPrescription()]
        let (vm, _) = makeVM(fetchResult: .success(prescriptions))

        #expect(vm.state == .idle)
        await vm.load()
        #expect(vm.state == .loaded(prescriptions))
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

    @Test("delete removes prescription from loaded state")
    func deleteRemovesPrescription() async {
        let first = MockPrescriptionRepository.makeTestPrescription(id: 1)
        let second = MockPrescriptionRepository.makeTestPrescription(id: 2, note: "Second")
        let repo = MockPrescriptionRepository()
        repo.fetchAllResult = .success([first, second])
        repo.deleteResult = .success(())
        let visitRepo = MockVisitRepository()
        let vm = PrescriptionListViewModel(repository: repo, visitRepository: visitRepo)

        await vm.load()
        await vm.delete(first)

        guard case .loaded(let remaining) = vm.state else {
            Issue.record("Expected .loaded, got \(String(describing: vm.state))")
            return
        }
        #expect(remaining.count == 1)
        #expect(remaining[0].id == 2)
        #expect(repo.lastDeletedId == 1)
    }

    @Test("delete failure transitions to .failed")
    func deleteFailure() async {
        let prescription = MockPrescriptionRepository.makeTestPrescription()
        let (vm, repo) = makeVM(fetchResult: .success([prescription]))
        repo.deleteResult = .failure(APIError.network)

        await vm.load()
        await vm.delete(prescription)

        #expect(vm.state == .failed(.network))
    }

    @Test("refresh after failure re-attempts and succeeds")
    func refreshAfterFailureSucceeds() async {
        let (vm, repo) = makeVM(fetchResult: .failure(APIError.network))

        await vm.load()
        #expect(vm.state == .failed(.network))

        let prescriptions = [MockPrescriptionRepository.makeTestPrescription()]
        repo.fetchAllResult = .success(prescriptions)
        await vm.refresh()
        #expect(vm.state == .loaded(prescriptions))
    }
}
