import Foundation
import OpenAPIRuntime

// MARK: - Repository protocol

protocol CatalogRepository: Sendable {
    func search(name: String, regionCode: String?) async throws -> [CatalogItem]
}

// MARK: - Narrow client protocol

protocol CatalogClient: Sendable {
    func searchCatalog(
        regionCode: String,
        name: String?
    ) async throws -> Operations.Search.Output
}

extension APIClient: CatalogClient {
    func searchCatalog(
        regionCode: String,
        name: String?
    ) async throws -> Operations.Search.Output {
        try await client.search(query: .init(regionCode: regionCode, name: name))
    }
}

// MARK: - Live implementation

final class LiveCatalogRepository: CatalogRepository {
    private let apiClient: any CatalogClient
    private let cache: any CacheStore
    // Default region for catalog queries — Czech Republic.
    private let defaultRegionCode: String

    init(
        apiClient: any CatalogClient,
        cache: any CacheStore,
        defaultRegionCode: String = "CZ"
    ) {
        self.apiClient = apiClient
        self.cache = cache
        self.defaultRegionCode = defaultRegionCode
    }

    func search(name: String, regionCode: String?) async throws -> [CatalogItem] {
        let region = regionCode ?? defaultRegionCode
        let key = "catalog.\(region).\(name.lowercased())"
        if let cached = cache.load([CatalogItem].self, forKey: key) {
            return cached
        }
        let output = try await apiClient.searchCatalog(regionCode: region, name: name)
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 5_242_880)
            let page = try Self.decoder.decode(Components.Schemas.PageCatalogItemResponse.self, from: data)
            let items = try (page.content ?? []).map { try CatalogItem.from($0) }
            cache.save(items, forKey: key)
            return items
        case .undocumented(let statusCode, _):
            if statusCode == 401 { throw APIError.unauthorized }
            throw APIError.server(status: statusCode)
        }
    }

    private static let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()
}
