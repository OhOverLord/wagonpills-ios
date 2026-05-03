#if DEBUG
import Foundation

struct PreviewCatalogRepository: CatalogRepository {
    var items: [CatalogItem]
    var error: APIError?

    init(items: [CatalogItem] = [], error: APIError? = nil) {
        self.items = items
        self.error = error
    }

    func search(name: String, regionCode: String?) async throws -> [CatalogItem] {
        if let error { throw error }
        guard name.count >= 2 else { return [] }
        let query = name.lowercased()
        return items.filter { item in
            item.name.lowercased().contains(query) ||
            item.aliases.contains { $0.lowercased().contains(query) }
        }
    }
}
#endif
