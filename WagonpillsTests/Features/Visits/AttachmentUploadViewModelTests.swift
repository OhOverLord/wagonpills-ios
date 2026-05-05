import Foundation
import Testing
@testable import Wagonpills

@Suite("AttachmentUploadViewModel")
@MainActor
struct AttachmentUploadViewModelTests {
    private static func file(_ name: String) -> AttachmentUploadViewModel.FileSelection {
        .init(data: Data(name.utf8), fileName: name, mimeType: "application/pdf")
    }

    @Test("upload single file success sets state to .done")
    func uploadSingleSuccess() async {
        let repo = MockVisitRepository()
        let attachment = MockVisitRepository.makeTestAttachment(id: 10, fileName: "report.pdf")
        repo.uploadResult = .success(attachment)

        let vm = AttachmentUploadViewModel(visitId: 1, repository: repo)
        await vm.upload(files: [Self.file("report.pdf")], note: "Annual report")

        guard case .done(let uploaded) = vm.uploadState else {
            Issue.record("Expected .done, got \(vm.uploadState)")
            return
        }
        #expect(uploaded.count == 1)
        #expect(uploaded[0].id == 10)
        #expect(repo.uploadCallCount == 1)
    }

    @Test("upload multiple files all succeed sets state to .done with all attachments")
    func uploadMultipleSuccess() async {
        let repo = MockVisitRepository()
        let first = MockVisitRepository.makeTestAttachment(id: 1, fileName: "a.pdf")
        let second = MockVisitRepository.makeTestAttachment(id: 2, fileName: "b.pdf")
        repo.uploadResults = [.success(first), .success(second)]

        let vm = AttachmentUploadViewModel(visitId: 1, repository: repo)
        await vm.upload(files: [Self.file("a.pdf"), Self.file("b.pdf")], note: nil)

        guard case .done(let uploaded) = vm.uploadState else {
            Issue.record("Expected .done, got \(vm.uploadState)")
            return
        }
        #expect(uploaded.count == 2)
        #expect(repo.uploadCallCount == 2)
    }

    @Test("upload with all failures sets state to .partialFailure with zero succeeded")
    func uploadAllFailure() async {
        let repo = MockVisitRepository()
        repo.uploadResult = .failure(APIError.network)

        let vm = AttachmentUploadViewModel(visitId: 1, repository: repo)
        await vm.upload(files: [Self.file("file.pdf")], note: nil)

        guard case .partialFailure(let succeeded, let failedCount, _) = vm.uploadState else {
            Issue.record("Expected .partialFailure, got \(vm.uploadState)")
            return
        }
        #expect(succeeded.isEmpty)
        #expect(failedCount == 1)
    }

    @Test("upload partial failure tracks succeeded and failed counts")
    func uploadPartialFailure() async {
        let repo = MockVisitRepository()
        let attachment = MockVisitRepository.makeTestAttachment(id: 1, fileName: "a.pdf")
        repo.uploadResults = [.success(attachment), .failure(APIError.network)]

        let vm = AttachmentUploadViewModel(visitId: 1, repository: repo)
        await vm.upload(files: [Self.file("a.pdf"), Self.file("b.pdf")], note: nil)

        guard case .partialFailure(let succeeded, let failedCount, _) = vm.uploadState else {
            Issue.record("Expected .partialFailure, got \(vm.uploadState)")
            return
        }
        #expect(succeeded.count == 1)
        #expect(failedCount == 1)
        #expect(repo.uploadCallCount == 2)
    }

    @Test("reset() returns uploadState to .idle")
    func resetState() async {
        let repo = MockVisitRepository()
        repo.uploadResult = .failure(APIError.network)

        let vm = AttachmentUploadViewModel(visitId: 1, repository: repo)
        await vm.upload(files: [Self.file("f.pdf")], note: nil)
        vm.reset()

        #expect(vm.uploadState == .idle)
    }
}
