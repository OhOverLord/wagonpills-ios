import Foundation
import Testing
@testable import Wagonpills

@Suite("CatalogPickerViewModel")
@MainActor
struct CatalogPickerViewModelTests {

    // MARK: - Short text (no search triggered)

    @Test("onSearchTextChanged() with text shorter than 2 chars clears results immediately")
    func shortTextClearsResults() {
        let repo = MockCatalogRepository()
        let vm = CatalogPickerViewModel(repository: repo)
        vm.searchText = "A"

        vm.onSearchTextChanged()

        #expect(vm.results.isEmpty)
        #expect(repo.searchCallCount == 0)
    }

    @Test("onSearchTextChanged() with empty text clears results immediately")
    func emptyTextClearsResults() {
        let repo = MockCatalogRepository()
        let vm = CatalogPickerViewModel(repository: repo)
        vm.searchText = ""

        vm.onSearchTextChanged()

        #expect(vm.results.isEmpty)
        #expect(repo.searchCallCount == 0)
    }

    @Test("onSearchTextChanged() clears searchError before starting")
    func clearsSearchError() {
        let repo = MockCatalogRepository()
        let vm = CatalogPickerViewModel(repository: repo)
        vm.searchText = "As"

        vm.onSearchTextChanged()

        #expect(vm.searchError == nil)
    }

    // MARK: - Successful search (after debounce)

    @Test("search succeeds after debounce and sets results")
    func searchSuccessAfterDebounce() async throws {
        let repo = MockCatalogRepository()
        let item = MockCatalogRepository.makeTestItem(id: 1, name: "Aspirin")
        repo.searchResult = .success([item])

        let vm = CatalogPickerViewModel(repository: repo)
        vm.searchText = "Asp"
        vm.onSearchTextChanged()

        try await Task.sleep(for: .milliseconds(400))

        #expect(vm.results.count == 1)
        #expect(vm.results[0].name == "Aspirin")
        #expect(vm.isSearching == false)
        #expect(vm.searchError == nil)
    }

    @Test("search failure after debounce sets searchError and clears results")
    func searchFailureAfterDebounce() async throws {
        let repo = MockCatalogRepository()
        repo.searchResult = .failure(APIError.network)

        let vm = CatalogPickerViewModel(repository: repo)
        vm.searchText = "Ibu"
        vm.onSearchTextChanged()

        try await Task.sleep(for: .milliseconds(400))

        #expect(vm.results.isEmpty)
        #expect(vm.searchError == .network)
        #expect(vm.isSearching == false)
    }

    @Test("rapid successive calls only fire one search (debounce cancels prior task)")
    func debounceFiresOnce() async throws {
        let repo = MockCatalogRepository()
        repo.searchResult = .success([MockCatalogRepository.makeTestItem()])

        let vm = CatalogPickerViewModel(repository: repo)

        vm.searchText = "As"
        vm.onSearchTextChanged()
        vm.searchText = "Asp"
        vm.onSearchTextChanged()
        vm.searchText = "Aspi"
        vm.onSearchTextChanged()

        try await Task.sleep(for: .milliseconds(400))

        #expect(repo.searchCallCount == 1)
        #expect(repo.lastSearchQuery == "Aspi")
    }

    @Test("switching to short text during debounce cancels the pending search")
    func shortTextCancelsPendingSearch() async throws {
        let repo = MockCatalogRepository()
        repo.searchResult = .success([MockCatalogRepository.makeTestItem()])

        let vm = CatalogPickerViewModel(repository: repo)
        vm.searchText = "Asp"
        vm.onSearchTextChanged()

        vm.searchText = "A"
        vm.onSearchTextChanged()

        try await Task.sleep(for: .milliseconds(400))

        #expect(repo.searchCallCount == 0)
        #expect(vm.results.isEmpty)
    }

    @Test("empty results from search leaves results empty")
    func searchReturnsEmpty() async throws {
        let repo = MockCatalogRepository()
        repo.searchResult = .success([])

        let vm = CatalogPickerViewModel(repository: repo)
        vm.searchText = "XYZ"
        vm.onSearchTextChanged()

        try await Task.sleep(for: .milliseconds(400))

        #expect(vm.results.isEmpty)
        #expect(vm.searchError == nil)
        #expect(vm.isSearching == false)
    }
}
