import Foundation
@testable import Wagonpills

final class MockVisitRepository: VisitRepository, @unchecked Sendable {
    var fetchAllResult: Result<[Visit], Error> = .success([])
    var fetchByIdResult: Result<Visit, Error> = .failure(APIError.notFound)
    var createResult: Result<Visit, Error> = .failure(APIError.unexpected("not configured"))
    var updateResult: Result<Visit, Error> = .failure(APIError.unexpected("not configured"))
    var deleteResult: Result<Void, Error> = .success(())
    var uploadResult: Result<VisitAttachment, Error> = .failure(APIError.unexpected("not configured"))
    var uploadResults: [Result<VisitAttachment, Error>] = []
    var downloadResult: Result<Data, Error> = .success(Data())
    var deleteAttachmentResult: Result<Void, Error> = .success(())

    private(set) var fetchAllCallCount = 0
    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var uploadCallCount = 0
    private(set) var lastDeletedId: Int64?

    func fetchAll() async throws -> [Visit] {
        fetchAllCallCount += 1
        return try fetchAllResult.get()
    }

    func fetchById(_ id: Int64) async throws -> Visit {
        return try fetchByIdResult.get()
    }

    func create(_ request: VisitCreateRequest) async throws -> Visit {
        createCallCount += 1
        return try createResult.get()
    }

    func update(id: Int64, _ request: VisitUpdateRequest) async throws -> Visit {
        updateCallCount += 1
        return try updateResult.get()
    }

    func delete(id: Int64) async throws {
        deleteCallCount += 1
        lastDeletedId = id
        try deleteResult.get()
    }

    func uploadAttachment(
        visitId: Int64,
        data: Data,
        fileName: String,
        mimeType: String,
        note: String?
    ) async throws -> VisitAttachment {
        let index = uploadCallCount
        uploadCallCount += 1
        if !uploadResults.isEmpty {
            return try uploadResults[min(index, uploadResults.count - 1)].get()
        }
        return try uploadResult.get()
    }

    func downloadAttachment(visitId: Int64, attachmentId: Int64) async throws -> Data {
        return try downloadResult.get()
    }

    func deleteAttachment(visitId: Int64, attachmentId: Int64) async throws {
        try deleteAttachmentResult.get()
    }

    static func makeTestVisit(id: Int64 = 1, doctorName: String = "Dr. Smith") -> Visit {
        Visit(
            id: id,
            doctorName: doctorName,
            specialty: "Cardiology",
            visitAt: Date(timeIntervalSinceNow: -86_400),
            location: "City Hospital",
            diagnosis: "Stable",
            recommendations: nil,
            attachments: [],
            createdAt: Date(timeIntervalSinceNow: -86_400),
            updatedAt: Date()
        )
    }

    static func makeTestAttachment(id: Int64 = 1, fileName: String = "test.pdf") -> VisitAttachment {
        VisitAttachment(
            id: id,
            fileName: fileName,
            contentType: "application/pdf",
            fileSizeBytes: 12_345,
            uploadedAt: Date(),
            checksumSha256: nil,
            note: nil
        )
    }
}
