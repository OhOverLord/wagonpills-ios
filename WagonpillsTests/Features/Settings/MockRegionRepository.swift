@testable import Wagonpills

final class MockRegionRepository: RegionRepository {
    var fetchResult: Result<[Region], APIError> = .success([])

    func fetchEnabled() async throws -> [Region] {
        switch fetchResult {
        case .success(let regions): return regions
        case .failure(let error): throw error
        }
    }

    static func makeSampleRegions() -> [Region] {
        [
            Region(code: "CZ", name: "Czech Republic", isEnabled: true),
            Region(code: "SK", name: "Slovakia", isEnabled: true),
            Region(code: "DE", name: "Germany", isEnabled: true)
        ]
    }
}
