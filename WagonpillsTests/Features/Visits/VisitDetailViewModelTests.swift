import Foundation
import Testing
@testable import Wagonpills

@Suite("VisitDetailViewModel")
@MainActor
struct VisitDetailViewModelTests {

    private struct GenericError: Error {}

    // MARK: - load()

    @Test("load() success sets state to .loaded with the returned visit")
    func loadSuccess() async {
        let repo = MockVisitRepository()
        let visit = MockVisitRepository.makeTestVisit(id: 5)
        repo.fetchByIdResult = .success(visit)

        let vm = VisitDetailViewModel(visitId: 5, repository: repo)
        await vm.load()

        guard case .loaded(let loaded) = vm.state else {
            Issue.record("Expected .loaded, got \(vm.state)")
            return
        }
        #expect(loaded.id == 5)
    }

    @Test("load() with network failure sets state to .failed(.network)")
    func loadNetworkFailure() async {
        let repo = MockVisitRepository()
        repo.fetchByIdResult = .failure(APIError.network)

        let vm = VisitDetailViewModel(visitId: 1, repository: repo)
        await vm.load()

        #expect(vm.state == .failed(.network))
    }

    @Test("load() with generic Error sets state to .failed(.unexpected) via APIError.from")
    func loadGenericError() async {
        let repo = MockVisitRepository()
        repo.fetchByIdResult = .failure(GenericError())

        let vm = VisitDetailViewModel(visitId: 1, repository: repo)
        await vm.load()

        guard case .failed(let error) = vm.state, case .unexpected = error else {
            Issue.record("Expected .failed(.unexpected), got \(vm.state)")
            return
        }
    }

    // MARK: - downloadAndPreview(_:)

    @Test("downloadAndPreview(_:) success sets previewURL and clears isDownloadingAttachmentId")
    func downloadSuccess() async throws {
        let repo = MockVisitRepository()
        repo.downloadResult = .success(Data("PDF content".utf8))

        let vm = VisitDetailViewModel(visitId: 1, repository: repo)
        let attachment = MockVisitRepository.makeTestAttachment(id: 1, fileName: "report.pdf")

        await vm.downloadAndPreview(attachment)

        let url = try #require(vm.previewURL)
        #expect(vm.isDownloadingAttachmentId == nil)
        #expect(FileManager.default.fileExists(atPath: url.path))

        try? FileManager.default.removeItem(at: url)
    }

    @Test("downloadAndPreview(_:) with slash in fileName sanitizes name and sets previewURL")
    func downloadSanitizesSlashInFileName() async throws {
        let repo = MockVisitRepository()
        repo.downloadResult = .success(Data("image".utf8))

        let vm = VisitDetailViewModel(visitId: 1, repository: repo)
        let attachment = MockVisitRepository.makeTestAttachment(id: 2, fileName: "CC95F08C/L0/001.jpeg")

        await vm.downloadAndPreview(attachment)

        let url = try #require(vm.previewURL)
        #expect(vm.isDownloadingAttachmentId == nil)
        #expect(FileManager.default.fileExists(atPath: url.path))

        try? FileManager.default.removeItem(at: url)
    }

    @Test("downloadAndPreview(_:) failure sets downloadError and clears isDownloadingAttachmentId")
    func downloadFailure() async {
        let repo = MockVisitRepository()
        repo.downloadResult = .failure(APIError.network)

        let vm = VisitDetailViewModel(visitId: 1, repository: repo)
        let attachment = MockVisitRepository.makeTestAttachment(id: 1)

        await vm.downloadAndPreview(attachment)

        #expect(vm.previewURL == nil)
        #expect(vm.downloadError == .network)
        #expect(vm.isDownloadingAttachmentId == nil)
    }

    // MARK: - clearPreview() / clearDownloadError()

    @Test("clearPreview() sets previewURL to nil")
    func clearPreview() async throws {
        let repo = MockVisitRepository()
        repo.downloadResult = .success(Data("data".utf8))

        let vm = VisitDetailViewModel(visitId: 1, repository: repo)
        let attachment = MockVisitRepository.makeTestAttachment(id: 1)
        await vm.downloadAndPreview(attachment)

        let url = try #require(vm.previewURL)
        vm.clearPreview()

        #expect(vm.previewURL == nil)
        try? FileManager.default.removeItem(at: url)
    }

    @Test("clearDownloadError() sets downloadError to nil")
    func clearDownloadError() async {
        let repo = MockVisitRepository()
        repo.downloadResult = .failure(APIError.network)

        let vm = VisitDetailViewModel(visitId: 1, repository: repo)
        let attachment = MockVisitRepository.makeTestAttachment(id: 1)
        await vm.downloadAndPreview(attachment)

        #expect(vm.downloadError != nil)
        vm.clearDownloadError()
        #expect(vm.downloadError == nil)
    }

    // MARK: - deleteAttachment(_:)

    @Test("deleteAttachment(_:) success triggers a reload and reflects refreshed visit")
    func deleteAttachmentSuccess() async {
        let repo = MockVisitRepository()
        let reloadedVisit = MockVisitRepository.makeTestVisit(id: 1, doctorName: "Dr. Reloaded")
        repo.deleteAttachmentResult = .success(())
        repo.fetchByIdResult = .success(reloadedVisit)

        let vm = VisitDetailViewModel(visitId: 1, repository: repo)
        let attachment = MockVisitRepository.makeTestAttachment(id: 99)

        await vm.deleteAttachment(attachment)

        guard case .loaded(let visit) = vm.state else {
            Issue.record("Expected .loaded after delete, got \(vm.state)")
            return
        }
        #expect(visit.doctorName == "Dr. Reloaded")
        #expect(vm.isDeletingAttachment == false)
    }

    @Test("deleteAttachment(_:) failure sets state to .failed and clears isDeletingAttachment")
    func deleteAttachmentFailure() async {
        let repo = MockVisitRepository()
        repo.deleteAttachmentResult = .failure(APIError.network)

        let vm = VisitDetailViewModel(visitId: 1, repository: repo)
        let attachment = MockVisitRepository.makeTestAttachment(id: 1)

        await vm.deleteAttachment(attachment)

        #expect(vm.state == .failed(.network))
        #expect(vm.isDeletingAttachment == false)
    }
}
