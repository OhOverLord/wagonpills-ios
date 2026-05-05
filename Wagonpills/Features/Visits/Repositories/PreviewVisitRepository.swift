#if DEBUG
import Foundation

final class PreviewVisitRepository: VisitRepository {
    private var visits: [Visit]
    var error: APIError?
    var uploadError: APIError?
    var downloadData: Data

    init(visits: [Visit] = PreviewVisitRepository.makeSampleVisits(), error: APIError? = nil) {
        self.visits = visits
        self.error = error
        self.downloadData = Data()
    }

    func fetchAll() async throws -> [Visit] {
        if let error { throw error }
        return visits
    }

    func fetchById(_ id: Int64) async throws -> Visit {
        if let error { throw error }
        guard let visit = visits.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return visit
    }

    func create(_ request: VisitCreateRequest) async throws -> Visit {
        if let error { throw error }
        let visit = Visit(
            id: Int64.random(in: 100...9_999),
            doctorName: request.doctorName,
            specialty: request.specialty,
            visitAt: request.visitAt,
            location: request.location,
            diagnosis: request.diagnosis,
            recommendations: request.recommendations,
            attachments: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        visits.append(visit)
        return visit
    }

    func update(id: Int64, _ request: VisitUpdateRequest) async throws -> Visit {
        if let error { throw error }
        guard let index = visits.firstIndex(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        var updated = visits[index]
        if let name = request.doctorName { updated.doctorName = name }
        if let specialty = request.specialty { updated.specialty = specialty }
        if let visitAt = request.visitAt { updated.visitAt = visitAt }
        if let location = request.location { updated.location = location }
        if let diagnosis = request.diagnosis { updated.diagnosis = diagnosis }
        if let recommendations = request.recommendations { updated.recommendations = recommendations }
        visits[index] = updated
        return updated
    }

    func delete(id: Int64) async throws {
        if let error { throw error }
        visits.removeAll { $0.id == id }
    }

    func uploadAttachment(
        visitId: Int64,
        data: Data,
        fileName: String,
        mimeType: String,
        note: String?
    ) async throws -> VisitAttachment {
        if let error = uploadError { throw error }
        let attachment = VisitAttachment(
            id: Int64.random(in: 100...9_999),
            fileName: fileName,
            contentType: mimeType,
            fileSizeBytes: Int64(data.count),
            uploadedAt: Date(),
            checksumSha256: nil,
            note: note
        )
        if let index = visits.firstIndex(where: { $0.id == visitId }) {
            visits[index].attachments.append(attachment)
        }
        return attachment
    }

    func downloadAttachment(visitId: Int64, attachmentId: Int64) async throws -> Data {
        if let error { throw error }
        return downloadData
    }

    func deleteAttachment(visitId: Int64, attachmentId: Int64) async throws {
        if let error { throw error }
        if let visitIndex = visits.firstIndex(where: { $0.id == visitId }) {
            visits[visitIndex].attachments.removeAll { $0.id == attachmentId }
        }
    }

    static func makeSampleVisits() -> [Visit] {
        let now = Date()
        return [
            Visit(
                id: 1,
                doctorName: "Dr. Jan Novák",
                specialty: "Cardiology",
                visitAt: Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now,
                location: "Prague General Hospital",
                diagnosis: "Mild hypertension, stable",
                recommendations: "Continue current medication, reduce salt intake",
                attachments: [
                    VisitAttachment(
                        id: 1,
                        fileName: "blood_test.pdf",
                        contentType: "application/pdf",
                        fileSizeBytes: 245_760,
                        uploadedAt: Calendar.current.date(byAdding: .day, value: -13, to: now) ?? now,
                        checksumSha256: nil,
                        note: "Annual blood test results"
                    )
                ],
                createdAt: Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .day, value: -13, to: now) ?? now
            ),
            Visit(
                id: 2,
                doctorName: "Dr. Eva Procházková",
                specialty: "General Practice",
                visitAt: Calendar.current.date(byAdding: .month, value: -2, to: now) ?? now,
                location: nil,
                diagnosis: nil,
                recommendations: "Follow up in 3 months",
                attachments: [],
                createdAt: Calendar.current.date(byAdding: .month, value: -2, to: now) ?? now,
                updatedAt: Calendar.current.date(byAdding: .month, value: -2, to: now) ?? now
            )
        ]
    }
}
#endif
