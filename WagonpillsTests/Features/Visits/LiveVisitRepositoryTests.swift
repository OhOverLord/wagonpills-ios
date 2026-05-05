import Foundation
import Testing
@testable import Wagonpills

// MARK: - Shared setup

private struct LiveRepositorySUT {
    let repo: LiveVisitRepository
    let client: MockVisitClient
    let cache: MockCacheStore

    init() {
        let client = MockVisitClient()
        let cache = MockCacheStore()
        repo = LiveVisitRepository(apiClient: client, cache: cache)
        self.client = client
        self.cache = cache
    }
}

private let visitsCacheKey = "visits.list"

// MARK: - fetchAll / fetchById

@Suite("LiveVisitRepository — fetch")
struct LiveVisitRepositoryFetchTests {

    @Test("fetchAll() success decodes visits and saves to cache")
    func fetchAllSuccess() async throws {
        let sut = LiveRepositorySUT()
        let dto = MockVisitClient.makeVisitDTO(id: 42)
        sut.client.getVisitsScenario = .successVisits([dto])

        let visits = try await sut.repo.fetchAll()

        #expect(visits.count == 1)
        #expect(visits[0].id == 42)
        #expect(sut.cache.hasValue(forKey: visitsCacheKey))
    }

    @Test("fetchAll() server error with cache returns cached data")
    func fetchAllCacheFallbackOnAPIError() async throws {
        let sut = LiveRepositorySUT()
        let cachedVisit = MockVisitRepository.makeTestVisit(id: 7)
        sut.cache.save([cachedVisit], forKey: visitsCacheKey)
        sut.client.getVisitsScenario = .serverError(500)

        let visits = try await sut.repo.fetchAll()

        #expect(visits.count == 1)
        #expect(visits[0].id == 7)
    }

    @Test("fetchAll() generic network error with cache returns cached data")
    func fetchAllCacheFallbackOnGenericError() async throws {
        let sut = LiveRepositorySUT()
        let cachedVisit = MockVisitRepository.makeTestVisit(id: 3)
        sut.cache.save([cachedVisit], forKey: visitsCacheKey)
        sut.client.getVisitsScenario = .networkError(URLError(.timedOut))

        let visits = try await sut.repo.fetchAll()

        #expect(visits.count == 1)
        #expect(visits[0].id == 3)
    }

    @Test("fetchAll() server error without cache throws APIError.server")
    func fetchAllNoFallbackThrows() async {
        let sut = LiveRepositorySUT()
        sut.client.getVisitsScenario = .serverError(503)

        do {
            _ = try await sut.repo.fetchAll()
            Issue.record("Expected throw")
        } catch let error as APIError {
            guard case .server(let status) = error else {
                Issue.record("Expected .server, got \(error)")
                return
            }
            #expect(status == 503)
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("fetchAll() malformed JSON without cache throws APIError.decoding")
    func fetchAllBadJSONThrows() async {
        let sut = LiveRepositorySUT()
        sut.client.getVisitsScenario = .badJSON

        do {
            _ = try await sut.repo.fetchAll()
            Issue.record("Expected throw")
        } catch let error as APIError {
            #expect(error == .decoding)
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("fetchById() success returns decoded visit")
    func fetchByIdSuccess() async throws {
        let sut = LiveRepositorySUT()
        let dto = MockVisitClient.makeVisitDTO(id: 99, doctorName: "Dr. House")
        sut.client.getVisitScenario = .successVisit(dto)

        let visit = try await sut.repo.fetchById(99)

        #expect(visit.id == 99)
        #expect(visit.doctorName == "Dr. House")
    }

    @Test("fetchById() notFound throws APIError.notFound")
    func fetchByIdNotFound() async {
        let sut = LiveRepositorySUT()
        sut.client.getVisitScenario = .notFound

        do {
            _ = try await sut.repo.fetchById(1)
            Issue.record("Expected throw")
        } catch let error as APIError {
            #expect(error == .notFound)
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("fetchById() undocumented response throws APIError.server")
    func fetchByIdUndocumented() async {
        let sut = LiveRepositorySUT()
        sut.client.getVisitScenario = .serverError(502)

        do {
            _ = try await sut.repo.fetchById(1)
            Issue.record("Expected throw")
        } catch let error as APIError {
            guard case .server(let status) = error else {
                Issue.record("Expected .server, got \(error)")
                return
            }
            #expect(status == 502)
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("fetchById() malformed JSON throws APIError.decoding")
    func fetchByIdBadJSON() async {
        let sut = LiveRepositorySUT()
        sut.client.getVisitScenario = .badJSON

        do {
            _ = try await sut.repo.fetchById(1)
            Issue.record("Expected throw")
        } catch let error as APIError {
            #expect(error == .decoding)
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("fetchById() generic error maps to APIError via APIError.from")
    func fetchByIdGenericError() async {
        let sut = LiveRepositorySUT()
        sut.client.getVisitScenario = .networkError(URLError(.notConnectedToInternet))

        do {
            _ = try await sut.repo.fetchById(1)
            Issue.record("Expected throw")
        } catch let error as APIError {
            #expect(error == .network)
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }
}

// MARK: - create / update / delete

@Suite("LiveVisitRepository — mutations")
struct LiveVisitRepositoryMutationTests {

    @Test("create() success returns decoded visit and invalidates cache")
    func createSuccess() async throws {
        let sut = LiveRepositorySUT()
        let cachedVisit = MockVisitRepository.makeTestVisit(id: 1)
        sut.cache.save([cachedVisit], forKey: visitsCacheKey)

        let dto = MockVisitClient.makeVisitDTO(id: 55)
        sut.client.createVisitScenario = .successVisit(dto)

        let request = VisitCreateRequest(
            doctorName: "Dr. New", specialty: nil, visitAt: Date(),
            location: nil, diagnosis: nil, recommendations: nil
        )
        let visit = try await sut.repo.create(request)

        #expect(visit.id == 55)
        #expect(!sut.cache.hasValue(forKey: visitsCacheKey))
    }

    @Test("create() badRequest throws APIError.validation")
    func createBadRequest() async {
        let sut = LiveRepositorySUT()
        sut.client.createVisitScenario = .badRequest

        do {
            _ = try await sut.repo.create(VisitCreateRequest(
                doctorName: nil, specialty: nil, visitAt: Date(),
                location: nil, diagnosis: nil, recommendations: nil
            ))
            Issue.record("Expected throw")
        } catch let error as APIError {
            guard case .validation = error else {
                Issue.record("Expected .validation, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("create() undocumented response throws APIError.server")
    func createUndocumented() async {
        let sut = LiveRepositorySUT()
        sut.client.createVisitScenario = .serverError(500)

        do {
            _ = try await sut.repo.create(VisitCreateRequest(
                doctorName: nil, specialty: nil, visitAt: Date(),
                location: nil, diagnosis: nil, recommendations: nil
            ))
            Issue.record("Expected throw")
        } catch let error as APIError {
            guard case .server = error else {
                Issue.record("Expected .server, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("update() success returns decoded visit and invalidates cache")
    func updateSuccess() async throws {
        let sut = LiveRepositorySUT()
        let cachedVisit = MockVisitRepository.makeTestVisit(id: 1)
        sut.cache.save([cachedVisit], forKey: visitsCacheKey)

        let dto = MockVisitClient.makeVisitDTO(id: 1, doctorName: "Dr. Updated")
        sut.client.updateVisitScenario = .successVisit(dto)

        let request = VisitUpdateRequest(
            doctorName: "Dr. Updated", specialty: nil, visitAt: nil,
            location: nil, diagnosis: nil, recommendations: nil
        )
        let visit = try await sut.repo.update(id: 1, request)

        #expect(visit.doctorName == "Dr. Updated")
        #expect(!sut.cache.hasValue(forKey: visitsCacheKey))
    }

    @Test("update() undocumented response throws APIError.server")
    func updateUndocumented() async {
        let sut = LiveRepositorySUT()
        sut.client.updateVisitScenario = .serverError(500)

        do {
            _ = try await sut.repo.update(id: 1, VisitUpdateRequest(
                doctorName: nil, specialty: nil, visitAt: nil,
                location: nil, diagnosis: nil, recommendations: nil
            ))
            Issue.record("Expected throw")
        } catch let error as APIError {
            guard case .server = error else {
                Issue.record("Expected .server, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("delete() success completes and invalidates cache")
    func deleteSuccess() async throws {
        let sut = LiveRepositorySUT()
        let cachedVisit = MockVisitRepository.makeTestVisit(id: 5)
        sut.cache.save([cachedVisit], forKey: visitsCacheKey)
        sut.client.deleteVisitScenario = .successDelete

        try await sut.repo.delete(id: 5)

        #expect(!sut.cache.hasValue(forKey: visitsCacheKey))
    }

    @Test("delete() undocumented response throws APIError.server")
    func deleteUndocumented() async {
        let sut = LiveRepositorySUT()
        sut.client.deleteVisitScenario = .serverError(500)

        do {
            try await sut.repo.delete(id: 1)
            Issue.record("Expected throw")
        } catch let error as APIError {
            guard case .server = error else {
                Issue.record("Expected .server, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }
}

// MARK: - attachments

@Suite("LiveVisitRepository — attachments")
struct LiveVisitRepositoryAttachmentTests {

    @Test("uploadAttachment() success returns decoded attachment and invalidates cache")
    func uploadSuccess() async throws {
        let sut = LiveRepositorySUT()
        let cachedVisit = MockVisitRepository.makeTestVisit(id: 1)
        sut.cache.save([cachedVisit], forKey: visitsCacheKey)

        let dto = MockVisitClient.makeAttachmentDTO(id: 77, fileName: "scan.pdf")
        sut.client.uploadAttachmentScenario = .successAttachment(dto)

        let attachment = try await sut.repo.uploadAttachment(
            visitId: 1, data: Data("bytes".utf8),
            fileName: "scan.pdf", mimeType: "application/pdf", note: nil
        )

        #expect(attachment.id == 77)
        #expect(attachment.fileName == "scan.pdf")
        #expect(!sut.cache.hasValue(forKey: visitsCacheKey))
    }

    @Test("uploadAttachment() notFound throws APIError.notFound")
    func uploadNotFound() async {
        let sut = LiveRepositorySUT()
        sut.client.uploadAttachmentScenario = .notFound

        do {
            _ = try await sut.repo.uploadAttachment(
                visitId: 999, data: Data(), fileName: "f.pdf", mimeType: "application/pdf", note: nil
            )
            Issue.record("Expected throw")
        } catch let error as APIError {
            #expect(error == .notFound)
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("uploadAttachment() malformed JSON response throws APIError.decoding")
    func uploadBadJSON() async {
        let sut = LiveRepositorySUT()
        sut.client.uploadAttachmentScenario = .badJSON

        do {
            _ = try await sut.repo.uploadAttachment(
                visitId: 1, data: Data(), fileName: "f.pdf", mimeType: "application/pdf", note: nil
            )
            Issue.record("Expected throw")
        } catch let error as APIError {
            #expect(error == .decoding)
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("downloadAttachment() success returns raw file data")
    func downloadSuccess() async throws {
        let sut = LiveRepositorySUT()
        let expectedData = Data("file-content".utf8)
        sut.client.downloadAttachmentScenario = .successDownload(expectedData)

        let data = try await sut.repo.downloadAttachment(visitId: 1, attachmentId: 1)

        #expect(data == expectedData)
    }

    @Test("downloadAttachment() undocumented response throws APIError.server")
    func downloadUndocumented() async {
        let sut = LiveRepositorySUT()
        sut.client.downloadAttachmentScenario = .serverError(500)

        do {
            _ = try await sut.repo.downloadAttachment(visitId: 1, attachmentId: 1)
            Issue.record("Expected throw")
        } catch let error as APIError {
            guard case .server = error else {
                Issue.record("Expected .server, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }

    @Test("deleteAttachment() success completes and invalidates cache")
    func deleteAttachmentSuccess() async throws {
        let sut = LiveRepositorySUT()
        let cachedVisit = MockVisitRepository.makeTestVisit(id: 1)
        sut.cache.save([cachedVisit], forKey: visitsCacheKey)
        sut.client.deleteAttachmentScenario = .successDelete

        try await sut.repo.deleteAttachment(visitId: 1, attachmentId: 10)

        #expect(!sut.cache.hasValue(forKey: visitsCacheKey))
    }

    @Test("deleteAttachment() undocumented response throws APIError.server")
    func deleteAttachmentUndocumented() async {
        let sut = LiveRepositorySUT()
        sut.client.deleteAttachmentScenario = .serverError(500)

        do {
            try await sut.repo.deleteAttachment(visitId: 1, attachmentId: 1)
            Issue.record("Expected throw")
        } catch let error as APIError {
            guard case .server = error else {
                Issue.record("Expected .server, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }
}
