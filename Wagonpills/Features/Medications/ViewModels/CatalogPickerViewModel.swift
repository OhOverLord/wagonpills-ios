import Foundation
import Observation

@MainActor
@Observable
final class CatalogPickerViewModel {
    private(set) var results: [CatalogItem] = []
    private(set) var isSearching: Bool = false
    private(set) var searchError: APIError?
    var searchText: String = ""

    private let repository: any CatalogRepository
    private var searchTask: Task<Void, Never>?

    init(repository: any CatalogRepository) {
        self.repository = repository
    }

    func onSearchTextChanged() {
        searchTask?.cancel()
        searchError = nil
        let text = searchText
        guard text.count >= 2 else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(text)
        }
    }

    private func performSearch(_ query: String) async {
        guard !Task.isCancelled else { return }
        isSearching = true
        do {
            results = try await repository.search(name: query, regionCode: nil)
        } catch let error as APIError {
            searchError = error
            results = []
        } catch {
            searchError = APIError.from(error)
            results = []
        }
        isSearching = false
    }
}
