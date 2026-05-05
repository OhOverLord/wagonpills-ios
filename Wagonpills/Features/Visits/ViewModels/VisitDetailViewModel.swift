import Foundation
import Observation

@MainActor
@Observable
final class VisitDetailViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded(Visit)
        case failed(APIError)
    }

    private(set) var state: LoadState = .loading
    var previewURL: URL?
    private(set) var isDownloadingAttachmentId: Int64?
    private(set) var downloadError: APIError?
    private(set) var isDeletingAttachment = false

    let visitId: Int64
    let repository: any VisitRepository

    init(visitId: Int64, repository: any VisitRepository) {
        self.visitId = visitId
        self.repository = repository
    }

    func load() async {
        do {
            let visit = try await repository.fetchById(visitId)
            state = .loaded(visit)
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
    }

    func downloadAndPreview(_ attachment: VisitAttachment) async {
        isDownloadingAttachmentId = attachment.id
        downloadError = nil
        do {
            let data = try await repository.downloadAttachment(
                visitId: visitId,
                attachmentId: attachment.id
            )
            let safeName = attachment.fileName.replacingOccurrences(of: "/", with: "_")
            let uniqueName = "\(UUID().uuidString)-\(safeName)"
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(uniqueName)
            try data.write(to: tempURL)
            previewURL = tempURL
        } catch let error as APIError {
            downloadError = error
        } catch {
            downloadError = .from(error)
        }
        isDownloadingAttachmentId = nil
    }

    func clearPreview() {
        previewURL = nil
    }

    func clearDownloadError() {
        downloadError = nil
    }

    func deleteAttachment(_ attachment: VisitAttachment) async {
        isDeletingAttachment = true
        do {
            try await repository.deleteAttachment(visitId: visitId, attachmentId: attachment.id)
            await load()
        } catch let error as APIError {
            state = .failed(error)
        } catch {
            state = .failed(APIError.from(error))
        }
        isDeletingAttachment = false
    }
}
