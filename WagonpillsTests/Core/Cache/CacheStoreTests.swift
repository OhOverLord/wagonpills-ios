import Foundation
import Testing
@testable import Wagonpills

@Suite("CacheStore")
struct CacheStoreTests {
    private struct Item: Codable, Equatable {
        let id: Int
        let name: String
    }

    // MARK: URLCacheStore round-trip

    @Test("save then load returns the original value")
    func roundTrip() {
        let cache = URLCache(memoryCapacity: 1_024_000, diskCapacity: 0)
        let store = URLCacheStore(cache: cache)
        let original = Item(id: 42, name: "Metformin")

        store.save(original, forKey: "test.item")
        let loaded = store.load(Item.self, forKey: "test.item")

        #expect(loaded == original)
    }

    @Test("load returns nil when key is absent")
    func loadMissing() {
        let cache = URLCache(memoryCapacity: 1_024_000, diskCapacity: 0)
        let store = URLCacheStore(cache: cache)
        #expect(store.load(Item.self, forKey: "no.such.key") == nil)
    }

    @Test("remove clears a previously saved value")
    func removeClears() {
        let cache = URLCache(memoryCapacity: 1_024_000, diskCapacity: 0)
        let store = URLCacheStore(cache: cache)
        store.save(Item(id: 1, name: "Aspirin"), forKey: "remove.test")
        store.remove(forKey: "remove.test")
        #expect(store.load(Item.self, forKey: "remove.test") == nil)
    }

    @Test("save overwrites a previously saved value")
    func overwrite() {
        let cache = URLCache(memoryCapacity: 1_024_000, diskCapacity: 0)
        let store = URLCacheStore(cache: cache)
        store.save(Item(id: 1, name: "Old"), forKey: "overwrite.test")
        store.save(Item(id: 2, name: "New"), forKey: "overwrite.test")
        #expect(store.load(Item.self, forKey: "overwrite.test") == Item(id: 2, name: "New"))
    }

    // MARK: MockCacheStore round-trip

    @Test("MockCacheStore round-trip")
    func mockRoundTrip() {
        let store = MockCacheStore()
        let original = Item(id: 7, name: "Ibuprofen")
        store.save(original, forKey: "mock.item")
        #expect(store.load(Item.self, forKey: "mock.item") == original)
    }
}
