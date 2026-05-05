import Foundation
import Testing
@testable import Wagonpills

@Suite("VisitListViewModel")
@MainActor
struct VisitListViewModelTests {

    @Test("load() fetches visits and sets state to .loaded")
    func loadSuccess() async {
        let repo = MockVisitRepository()
        let visits = [
            MockVisitRepository.makeTestVisit(id: 1),
            MockVisitRepository.makeTestVisit(id: 2)
        ]
        repo.fetchAllResult = .success(visits)

        let vm = VisitListViewModel(repository: repo)
        await vm.load()

        guard case .loaded(let loaded) = vm.state else {
            Issue.record("Expected .loaded, got \(vm.state)")
            return
        }
        #expect(loaded.count == 2)
        #expect(repo.fetchAllCallCount == 1)
    }

    @Test("load() with empty result sets state to .empty")
    func loadEmpty() async {
        let repo = MockVisitRepository()
        repo.fetchAllResult = .success([])

        let vm = VisitListViewModel(repository: repo)
        await vm.load()

        #expect(vm.state == .empty)
    }

    @Test("load() with network failure sets state to .failed")
    func loadNetworkFailure() async {
        let repo = MockVisitRepository()
        repo.fetchAllResult = .failure(APIError.network)

        let vm = VisitListViewModel(repository: repo)
        await vm.load()

        #expect(vm.state == .failed(.network))
    }

    @Test("delete() removes visit from loaded list on success")
    func deleteSuccess() async {
        let repo = MockVisitRepository()
        let visit1 = MockVisitRepository.makeTestVisit(id: 1)
        let visit2 = MockVisitRepository.makeTestVisit(id: 2)
        repo.fetchAllResult = .success([visit1, visit2])
        repo.deleteResult = .success(())

        let vm = VisitListViewModel(repository: repo)
        await vm.load()
        await vm.delete(visit1)

        guard case .loaded(let remaining) = vm.state else {
            Issue.record("Expected .loaded, got \(vm.state)")
            return
        }
        #expect(remaining.count == 1)
        #expect(remaining[0].id == 2)
        #expect(repo.lastDeletedId == 1)
    }

    @Test("delete() last visit sets state to .empty")
    func deleteLastVisit() async {
        let repo = MockVisitRepository()
        let visit = MockVisitRepository.makeTestVisit(id: 1)
        repo.fetchAllResult = .success([visit])
        repo.deleteResult = .success(())

        let vm = VisitListViewModel(repository: repo)
        await vm.load()
        await vm.delete(visit)

        #expect(vm.state == .empty)
    }

    @Test("visits sorted descending by visitAt after load")
    func sortedDescending() async {
        let repo = MockVisitRepository()
        let older = Visit(
            id: 1, doctorName: nil, specialty: nil,
            visitAt: Date(timeIntervalSinceNow: -7_776_000),
            location: nil, diagnosis: nil, recommendations: nil,
            attachments: [], createdAt: Date(), updatedAt: Date()
        )
        let newer = Visit(
            id: 2, doctorName: nil, specialty: nil,
            visitAt: Date(timeIntervalSinceNow: -86_400),
            location: nil, diagnosis: nil, recommendations: nil,
            attachments: [], createdAt: Date(), updatedAt: Date()
        )
        repo.fetchAllResult = .success([older, newer])

        let vm = VisitListViewModel(repository: repo)
        await vm.load()

        guard case .loaded(let loaded) = vm.state else {
            Issue.record("Expected .loaded")
            return
        }
        #expect(loaded[0].id == 2)
        #expect(loaded[1].id == 1)
    }
}
