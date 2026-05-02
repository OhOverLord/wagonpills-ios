import Foundation
@testable import Wagonpills

final class MockCacheStore: CacheStore, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = storage[key] else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, forKey key: String) {
        storage[key] = try? encoder.encode(value)
    }

    func remove(forKey key: String) {
        storage.removeValue(forKey: key)
    }

    var isEmpty: Bool { storage.isEmpty }
    func hasValue(forKey key: String) -> Bool { storage[key] != nil }
}
