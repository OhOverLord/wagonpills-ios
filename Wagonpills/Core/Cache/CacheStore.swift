import Foundation

protocol CacheStore: Sendable {
    func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T?
    func save<T: Encodable>(_ value: T, forKey key: String)
    func remove(forKey key: String)
}

// URLCache-backed implementation. Memory + disk eviction is handled automatically.
// Cache-first with network fallback strategy: stale-while-revalidate would be more
// elegant but adds concurrency complexity not warranted for a thesis prototype.
final class URLCacheStore: CacheStore, @unchecked Sendable {
    private let cache: URLCache
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(cache: URLCache = .shared) {
        self.cache = cache
    }

    func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard
            let request = makeRequest(forKey: key),
            let cached = cache.cachedResponse(for: request)
        else { return nil }
        do {
            return try decoder.decode(type, from: cached.data)
        } catch {
            #if DEBUG
            print("[CacheStore] decode error for key '\(key)': \(error)")
            #endif
            return nil
        }
    }

    func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let url = URL(string: "cache://wagonpills/\(key)") else { return }
        let request = URLRequest(url: url)
        do {
            let data = try encoder.encode(value)
            guard let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Cache-Control": "max-age=300"]
            ) else { return }
            cache.storeCachedResponse(CachedURLResponse(response: httpResponse, data: data), for: request)
        } catch {
            #if DEBUG
            print("[CacheStore] encode error for key '\(key)': \(error)")
            #endif
        }
    }

    func remove(forKey key: String) {
        guard let request = makeRequest(forKey: key) else { return }
        cache.removeCachedResponse(for: request)
    }

    private func makeRequest(forKey key: String) -> URLRequest? {
        guard let url = URL(string: "cache://wagonpills/\(key)") else { return nil }
        return URLRequest(url: url)
    }
}
