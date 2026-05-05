import Foundation

struct Visit: Identifiable, Equatable, Sendable, Codable {
    let id: Int64
    var doctorName: String?
    var specialty: String?
    var visitAt: Date
    var location: String?
    var diagnosis: String?
    var recommendations: String?
    var attachments: [VisitAttachment]
    let createdAt: Date
    let updatedAt: Date
}

struct VisitAttachment: Identifiable, Equatable, Sendable, Codable {
    let id: Int64
    let fileName: String
    let contentType: String
    let fileSizeBytes: Int64
    let uploadedAt: Date
    let checksumSha256: String?
    let note: String?
}

// MARK: - DTO mapping

extension Visit {
    static func from(_ dto: Components.Schemas.DoctorVisitResponse) throws -> Visit {
        guard let id = dto.id else { throw APIError.decoding }
        guard let visitAt = dto.visitAt else { throw APIError.decoding }
        guard let createdAt = dto.createdAt else { throw APIError.decoding }
        guard let updatedAt = dto.updatedAt else { throw APIError.decoding }

        let attachments = try (dto.attachments ?? []).map { try VisitAttachment.from($0) }

        return Visit(
            id: id,
            doctorName: dto.doctorName,
            specialty: dto.specialty,
            visitAt: visitAt,
            location: dto.location,
            diagnosis: dto.diagnosis,
            recommendations: dto.recommendations,
            attachments: attachments,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension VisitAttachment {
    static func from(_ dto: Components.Schemas.AttachmentResponse) throws -> VisitAttachment {
        guard let id = dto.id else { throw APIError.decoding }
        guard let fileName = dto.fileName else { throw APIError.decoding }
        guard let contentType = dto.contentType else { throw APIError.decoding }
        guard let fileSizeBytes = dto.fileSizeBytes else { throw APIError.decoding }
        guard let uploadedAt = dto.uploadedAt else { throw APIError.decoding }

        return VisitAttachment(
            id: id,
            fileName: fileName,
            contentType: contentType,
            fileSizeBytes: fileSizeBytes,
            uploadedAt: uploadedAt,
            checksumSha256: dto.checksumSha256,
            note: dto.note
        )
    }
}
