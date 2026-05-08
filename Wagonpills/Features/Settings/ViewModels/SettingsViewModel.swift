import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    enum RegionState: Equatable {
        case idle
        case loading
        case loaded([Region])
        case failed(APIError)
    }

    @Published private(set) var regionState: RegionState = .idle
    @Published var selectedRegionCode: String {
        didSet { UserDefaults.standard.set(selectedRegionCode, forKey: "preferredRegionCode") }
    }

    private let regionRepository: any RegionRepository

    init(regionRepository: any RegionRepository) {
        self.regionRepository = regionRepository
        self.selectedRegionCode = UserDefaults.standard.string(forKey: "preferredRegionCode") ?? "CZ"
    }

    func loadRegions() async {
        guard regionState == .idle else { return }
        regionState = .loading
        do {
            let regions = try await regionRepository.fetchEnabled()
            regionState = .loaded(regions)
        } catch {
            regionState = .failed(APIError.from(error))
        }
    }
}
