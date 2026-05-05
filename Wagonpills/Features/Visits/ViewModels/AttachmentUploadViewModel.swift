import Foundation
import Observation

@MainActor
@Observable
final class AttachmentUploadViewModel {
    struct FileSelection: Equatable, Sendable {
        let data: Data
        let fileName: String
        let mimeType: String
    }

    enum UploadState: Equatable {
        case idle
        case uploading(current: Int, total: Int)
        case done([VisitAttachment])
        case partialFailure(succeeded: [VisitAttachment], failedCount: Int, lastError: String)
    }

    private(set) var uploadState: UploadState = .idle

    private let visitId: Int64
    private let repository: any VisitRepository

    init(visitId: Int64, repository: any VisitRepository) {
        self.visitId = visitId
        self.repository = repository
    }

    func upload(files: [FileSelection], note: String?) async {
        guard !files.isEmpty else { return }
        var uploaded: [VisitAttachment] = []
        var failedCount = 0
        var lastError = ""

        for (index, file) in files.enumerated() {
            uploadState = .uploading(current: index + 1, total: files.count)
            do {
                let attachment = try await repository.uploadAttachment(
                    visitId: visitId,
                    data: file.data,
                    fileName: file.fileName,
                    mimeType: file.mimeType,
                    note: note
                )
                uploaded.append(attachment)
            } catch {
                failedCount += 1
                lastError = error.localizedDescription
            }
        }

        uploadState = failedCount == 0
            ? .done(uploaded)
            : .partialFailure(succeeded: uploaded, failedCount: failedCount, lastError: lastError)
    }

    func reset() {
        uploadState = .idle
    }
}
