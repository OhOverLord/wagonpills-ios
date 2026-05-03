import Foundation
import Observation

@MainActor
@Observable
final class StockViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(summary: StockSummary, history: [StockMovement])
        case failed(APIError)
    }

    private(set) var state: State = .idle

    private let medicationId: Int64
    private let repository: any MedicationRepository

    init(medicationId: Int64, repository: any MedicationRepository) {
        self.medicationId = medicationId
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            async let summary = repository.fetchStockSummary(medicationId: medicationId)
            async let history = repository.fetchStockHistory(medicationId: medicationId)
            state = .loaded(summary: try await summary, history: try await history)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }

    func refresh() async {
        await load()
    }
}
