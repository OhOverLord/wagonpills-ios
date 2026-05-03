import Foundation
import Testing
@testable import Wagonpills

@Suite("StockViewModel")
@MainActor
struct StockViewModelTests {
    private static func makeSummary(
        medicationId: Int64 = 1,
        currentStock: Double = 20,
        lowStockThreshold: Double? = 10,
        isLowStock: Bool = false
    ) -> StockSummary {
        StockSummary(
            medicationId: medicationId,
            medicationName: "Aspirin",
            currentStock: currentStock,
            unit: .tablet,
            lowStockThreshold: lowStockThreshold,
            isLowStock: isLowStock
        )
    }

    private static func makeMovement(id: Int64, type: StockMovementType = .add) -> StockMovement {
        StockMovement(
            id: id, medicationId: 1, movementType: type,
            quantity: 10, unit: .tablet, relatedIntakeLogId: nil,
            note: nil, createdAt: Date()
        )
    }

    @Test("load() fetches both summary and history")
    func loadFetchesBothSummaryAndHistory() async {
        let repo = MockMedicationRepository()
        let summary = Self.makeSummary()
        let history = [Self.makeMovement(id: 1), Self.makeMovement(id: 2, type: .consume)]
        repo.fetchStockSummaryResult = .success(summary)
        repo.fetchStockHistoryResult = .success(history)
        let vm = StockViewModel(medicationId: 1, repository: repo)

        await vm.load()

        #expect(repo.fetchStockSummaryCallCount == 1)
        #expect(repo.fetchStockHistoryCallCount == 1)
        if case .loaded(let loadedSummary, let loadedHistory) = vm.state {
            #expect(loadedSummary == summary)
            #expect(loadedHistory.count == 2)
        } else {
            Issue.record("Expected .loaded, got \(vm.state)")
        }
    }

    @Test("load() transitions to .loading then .loaded")
    func loadTransitionsToLoadedState() async {
        let repo = MockMedicationRepository()
        repo.fetchStockSummaryResult = .success(Self.makeSummary())
        repo.fetchStockHistoryResult = .success([])
        let vm = StockViewModel(medicationId: 1, repository: repo)

        #expect(vm.state == .idle)
        await vm.load()
        if case .loaded = vm.state {
            // expected
        } else {
            Issue.record("Expected .loaded, got \(vm.state)")
        }
    }

    @Test("load() transitions to .failed on summary error")
    func loadFailsOnSummaryError() async {
        let repo = MockMedicationRepository()
        repo.fetchStockSummaryResult = .failure(APIError.server(status: 500))
        repo.fetchStockHistoryResult = .success([])
        let vm = StockViewModel(medicationId: 1, repository: repo)

        await vm.load()

        if case .failed(let error) = vm.state {
            #expect(error == .server(status: 500))
        } else {
            Issue.record("Expected .failed, got \(vm.state)")
        }
    }

    @Test("load() transitions to .failed on history error")
    func loadFailsOnHistoryError() async {
        let repo = MockMedicationRepository()
        repo.fetchStockSummaryResult = .success(Self.makeSummary())
        repo.fetchStockHistoryResult = .failure(APIError.server(status: 503))
        let vm = StockViewModel(medicationId: 1, repository: repo)

        await vm.load()

        if case .failed = vm.state {
            // expected — either fetch can cause failure
        } else {
            Issue.record("Expected .failed, got \(vm.state)")
        }
    }

    @Test("refresh() reloads data")
    func refreshReloadsData() async {
        let repo = MockMedicationRepository()
        repo.fetchStockSummaryResult = .success(Self.makeSummary())
        repo.fetchStockHistoryResult = .success([])
        let vm = StockViewModel(medicationId: 1, repository: repo)

        await vm.refresh()

        #expect(repo.fetchStockSummaryCallCount == 1)
        #expect(repo.fetchStockHistoryCallCount == 1)
    }

    @Test("loaded state exposes correct low-stock flag")
    func loadedStateExposesLowStockFlag() async {
        let repo = MockMedicationRepository()
        let summary = Self.makeSummary(currentStock: 3, lowStockThreshold: 10, isLowStock: true)
        repo.fetchStockSummaryResult = .success(summary)
        repo.fetchStockHistoryResult = .success([])
        let vm = StockViewModel(medicationId: 1, repository: repo)

        await vm.load()

        if case .loaded(let loadedSummary, _) = vm.state {
            #expect(loadedSummary.isLowStock)
        } else {
            Issue.record("Expected .loaded, got \(vm.state)")
        }
    }
}
