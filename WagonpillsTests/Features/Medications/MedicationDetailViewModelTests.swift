import Foundation
import Testing
@testable import Wagonpills

@Suite("MedicationDetailViewModel")
@MainActor
struct MedicationDetailViewModelTests {

    private struct GenericError: Error {}

    @Test("initial state is .loading")
    func initialStateIsLoading() {
        let repo = MockMedicationRepository()
        let vm = MedicationDetailViewModel(
            medicationId: 1,
            repository: repo,
            reminderRepository: MockReminderRepository(),
            intakeLogRepository: MockIntakeLogRepository(),
            catalogRepository: MockCatalogRepository()
        )

        #expect(vm.state == .loading)
    }

    @Test("load() success sets state to .loaded with the returned medication")
    func loadSuccess() async {
        let repo = MockMedicationRepository()
        let medication = MockMedicationRepository.makeTestMedication(id: 7, name: "Ibuprofen")
        repo.fetchByIdResult = .success(medication)

        let vm = MedicationDetailViewModel(
            medicationId: 7,
            repository: repo,
            reminderRepository: MockReminderRepository(),
            intakeLogRepository: MockIntakeLogRepository(),
            catalogRepository: MockCatalogRepository()
        )
        await vm.load()

        guard case .loaded(let loaded) = vm.state else {
            Issue.record("Expected .loaded, got \(vm.state)")
            return
        }
        #expect(loaded.id == 7)
        #expect(loaded.name == "Ibuprofen")
    }

    @Test("load() with APIError sets state to .failed with that error")
    func loadAPIError() async {
        let repo = MockMedicationRepository()
        repo.fetchByIdResult = .failure(APIError.notFound)

        let vm = MedicationDetailViewModel(
            medicationId: 99,
            repository: repo,
            reminderRepository: MockReminderRepository(),
            intakeLogRepository: MockIntakeLogRepository(),
            catalogRepository: MockCatalogRepository()
        )
        await vm.load()

        #expect(vm.state == .failed(.notFound))
    }

    @Test("load() with generic Error maps to .failed(.unexpected) via APIError.from")
    func loadGenericError() async {
        let repo = MockMedicationRepository()
        repo.fetchByIdResult = .failure(GenericError())

        let vm = MedicationDetailViewModel(
            medicationId: 1,
            repository: repo,
            reminderRepository: MockReminderRepository(),
            intakeLogRepository: MockIntakeLogRepository(),
            catalogRepository: MockCatalogRepository()
        )
        await vm.load()

        guard case .failed(let error) = vm.state, case .unexpected = error else {
            Issue.record("Expected .failed(.unexpected), got \(vm.state)")
            return
        }
    }

    @Test("load() with network error sets state to .failed(.network)")
    func loadNetworkError() async {
        let repo = MockMedicationRepository()
        repo.fetchByIdResult = .failure(APIError.network)

        let vm = MedicationDetailViewModel(
            medicationId: 1,
            repository: repo,
            reminderRepository: MockReminderRepository(),
            intakeLogRepository: MockIntakeLogRepository(),
            catalogRepository: MockCatalogRepository()
        )
        await vm.load()

        #expect(vm.state == .failed(.network))
    }
}
