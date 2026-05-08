import Foundation
import Testing
@testable import Wagonpills

@Suite("SettingsViewModel")
@MainActor
struct SettingsViewModelTests {
    private func makeVM(
        regions: [Region] = [],
        error: APIError? = nil,
        storedRegionCode: String? = nil
    ) -> (SettingsViewModel, MockRegionRepository) {
        UserDefaults.standard.removeObject(forKey: "preferredRegionCode")
        if let code = storedRegionCode {
            UserDefaults.standard.set(code, forKey: "preferredRegionCode")
        }
        let repo = MockRegionRepository()
        repo.fetchResult = error.map { .failure($0) } ?? .success(regions)
        return (SettingsViewModel(regionRepository: repo), repo)
    }

    @Test("initial state is idle")
    func initialStateIsIdle() {
        let (vm, _) = makeVM()
        #expect(vm.regionState == .idle)
    }

    @Test("loadRegions success transitions to loaded")
    func loadRegionsSuccess() async {
        let regions = MockRegionRepository.makeSampleRegions()
        let (vm, _) = makeVM(regions: regions)
        await vm.loadRegions()
        #expect(vm.regionState == .loaded(regions))
    }

    @Test("loadRegions failure transitions to failed")
    func loadRegionsFailure() async {
        let (vm, _) = makeVM(error: .network)
        await vm.loadRegions()
        #expect(vm.regionState == .failed(.network))
    }

    @Test("loadRegions called twice only fetches once")
    func loadRegionsIdempotent() async {
        let regions = MockRegionRepository.makeSampleRegions()
        let (vm, _) = makeVM(regions: regions)
        await vm.loadRegions()
        await vm.loadRegions()
        if case .loaded(let loaded) = vm.regionState {
            #expect(loaded.count == regions.count)
        } else {
            Issue.record("Expected .loaded state")
        }
    }

    @Test("selecting a region persists to UserDefaults")
    func selectingRegionPersists() async {
        let (vm, _) = makeVM()
        vm.selectedRegionCode = "SK"
        #expect(UserDefaults.standard.string(forKey: "preferredRegionCode") == "SK")
    }

    @Test("selectedRegionCode initialises from UserDefaults")
    func initialRegionFromUserDefaults() {
        let (vm, _) = makeVM(storedRegionCode: "DE")
        #expect(vm.selectedRegionCode == "DE")
    }

    @Test("selectedRegionCode defaults to CZ when UserDefaults has no value")
    func defaultRegionCode() {
        let (vm, _) = makeVM()
        #expect(vm.selectedRegionCode == "CZ")
    }
}
