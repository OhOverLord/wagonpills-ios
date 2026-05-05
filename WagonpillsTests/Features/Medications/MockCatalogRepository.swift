import Foundation
@testable import Wagonpills

final class MockCatalogRepository: CatalogRepository, @unchecked Sendable {
    var searchResult: Result<[CatalogItem], Error> = .success([])
    private(set) var searchCallCount = 0
    private(set) var lastSearchQuery: String?

    func search(name: String, regionCode: String?) async throws -> [CatalogItem] {
        searchCallCount += 1
        lastSearchQuery = name
        return try searchResult.get()
    }

    static func makeTestItem(id: Int64 = 1, name: String = "Aspirin") -> CatalogItem {
        CatalogItem(id: id, name: name, strength: "500 mg", form: "tablet", regionCode: "CZ", aliases: [])
    }
}
