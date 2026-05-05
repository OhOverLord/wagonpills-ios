import Foundation
import OpenAPIRuntime
@testable import Wagonpills

// MARK: - Scenario enum

enum VisitClientScenario {
    case successVisits([Components.Schemas.DoctorVisitResponse])
    case successVisit(Components.Schemas.DoctorVisitResponse)
    case successAttachment(Components.Schemas.AttachmentResponse)
    case successDownload(Data)
    case successDelete
    case notFound
    case badRequest
    case serverError(Int)
    case badJSON
    case networkError(Error)
}

// MARK: - MockVisitClient

final class MockVisitClient: VisitClient, @unchecked Sendable {

    var getVisitsScenario: VisitClientScenario = .serverError(500)
    var getVisitScenario: VisitClientScenario = .serverError(500)
    var createVisitScenario: VisitClientScenario = .serverError(500)
    var updateVisitScenario: VisitClientScenario = .serverError(500)
    var deleteVisitScenario: VisitClientScenario = .successDelete
    var uploadAttachmentScenario: VisitClientScenario = .serverError(500)
    var downloadAttachmentScenario: VisitClientScenario = .serverError(500)
    var deleteAttachmentScenario: VisitClientScenario = .successDelete

    // MARK: Protocol conformance

    func getVisits() async throws -> Operations.GetAll.Output {
        switch getVisitsScenario {
        case .successVisits(let dtos):
            return try .ok(.init(body: .any(HTTPBody(Self.encode(dtos)))))
        case .badJSON:
            return .ok(.init(body: .any(HTTPBody(Data("invalid-json".utf8)))))
        case .networkError(let error):
            throw error
        case .serverError(let code):
            return .undocumented(statusCode: code, .init())
        default:
            return .undocumented(statusCode: 500, .init())
        }
    }

    func createVisit(_ body: Components.Schemas.CreateDoctorVisitRequest) async throws -> Operations.Create.Output {
        switch createVisitScenario {
        case .successVisit(let dto):
            return try .created(.init(body: .any(HTTPBody(Self.encode(dto)))))
        case .badRequest:
            return .badRequest(.init(body: .any(HTTPBody(Data()))))
        case .serverError(let code):
            return .undocumented(statusCode: code, .init())
        default:
            return .undocumented(statusCode: 500, .init())
        }
    }

    func getVisit(id: Int64) async throws -> Operations.GetById.Output {
        switch getVisitScenario {
        case .successVisit(let dto):
            return try .ok(.init(body: .any(HTTPBody(Self.encode(dto)))))
        case .notFound:
            return .notFound(.init(body: .any(HTTPBody(Data()))))
        case .badJSON:
            return .ok(.init(body: .any(HTTPBody(Data("bad".utf8)))))
        case .networkError(let error):
            throw error
        case .serverError(let code):
            return .undocumented(statusCode: code, .init())
        default:
            return .undocumented(statusCode: 500, .init())
        }
    }

    func updateVisit(id: Int64, _ body: Components.Schemas.UpdateDoctorVisitRequest) async throws -> Operations.Update.Output {
        switch updateVisitScenario {
        case .successVisit(let dto):
            return try .ok(.init(body: .any(HTTPBody(Self.encode(dto)))))
        case .serverError(let code):
            return .undocumented(statusCode: code, .init())
        default:
            return .undocumented(statusCode: 500, .init())
        }
    }

    func deleteVisit(id: Int64) async throws -> Operations.Delete.Output {
        switch deleteVisitScenario {
        case .successDelete:
            return .ok
        case .serverError(let code):
            return .undocumented(statusCode: code, .init())
        default:
            return .undocumented(statusCode: 500, .init())
        }
    }

    func uploadVisitAttachment(
        visitId: Int64,
        note: String?,
        body: Operations.UploadAttachment.Input.Body
    ) async throws -> Operations.UploadAttachment.Output {
        switch uploadAttachmentScenario {
        case .successAttachment(let dto):
            return try .created(.init(body: .any(HTTPBody(Self.encode(dto)))))
        case .notFound:
            return .notFound(.init(body: .any(HTTPBody(Data()))))
        case .badJSON:
            return .created(.init(body: .any(HTTPBody(Data("bad".utf8)))))
        case .serverError(let code):
            return .undocumented(statusCode: code, .init())
        default:
            return .undocumented(statusCode: 500, .init())
        }
    }

    func downloadVisitAttachment(visitId: Int64, attachmentId: Int64) async throws -> Operations.DownloadAttachment.Output {
        switch downloadAttachmentScenario {
        case .successDownload(let data):
            return .ok(.init(body: .any(HTTPBody(data))))
        case .serverError(let code):
            return .undocumented(statusCode: code, .init())
        default:
            return .undocumented(statusCode: 500, .init())
        }
    }

    func deleteVisitAttachment(visitId: Int64, attachmentId: Int64) async throws -> Operations.DeleteAttachment.Output {
        switch deleteAttachmentScenario {
        case .successDelete:
            return .ok
        case .serverError(let code):
            return .undocumented(statusCode: code, .init())
        default:
            return .undocumented(statusCode: 500, .init())
        }
    }

    // MARK: - DTO factories

    static func makeVisitDTO(id: Int64 = 1, doctorName: String? = "Dr. Test") -> Components.Schemas.DoctorVisitResponse {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        return Components.Schemas.DoctorVisitResponse(
            id: id,
            doctorName: doctorName,
            specialty: nil,
            visitAt: now,
            location: nil,
            diagnosis: nil,
            recommendations: nil,
            attachments: [],
            createdAt: now,
            updatedAt: now
        )
    }

    static func makeAttachmentDTO(id: Int64 = 1, fileName: String = "report.pdf") -> Components.Schemas.AttachmentResponse {
        Components.Schemas.AttachmentResponse(
            id: id,
            fileName: fileName,
            contentType: "application/pdf",
            fileSizeBytes: 1_024,
            uploadedAt: Date(timeIntervalSince1970: 1_700_000_000),
            checksumSha256: nil,
            note: nil
        )
    }

    // MARK: - Private encoding

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        encoder.dateEncodingStrategy = .custom { date, enc in
            var container = enc.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return try encoder.encode(value)
    }
}
