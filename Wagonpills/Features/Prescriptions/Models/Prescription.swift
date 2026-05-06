import Foundation

struct Prescription: Identifiable, Equatable, Sendable, Codable {
    let id: Int64
    var doctorVisitId: Int64?
    var issuedAt: Date?
    var note: String?
    let createdAt: Date
    var items: [PrescriptionItem]
}

struct PrescriptionItem: Identifiable, Equatable, Sendable, Codable {
    let id: Int64
    let prescriptionId: Int64
    var medicationName: String
    var dosageText: String?
    var instructions: String?
    var durationDays: Int32?
}

// MARK: - Date helpers

// issuedAt uses format: date in the API spec (e.g. "2026-04-01"), not date-time.
private let issuedAtFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter
}()

extension String {
    var asIssuedAtDate: Date? { issuedAtFormatter.date(from: self) }
}

extension Date {
    var asIssuedAtString: String { issuedAtFormatter.string(from: self) }
}

// MARK: - DTO mapping

extension Prescription {
    static func from(
        _ dto: Components.Schemas.PrescriptionResponse,
        items: [PrescriptionItem] = []
    ) throws -> Prescription {
        guard let id = dto.id else { throw APIError.decoding }
        guard let createdAt = dto.createdAt else { throw APIError.decoding }
        return Prescription(
            id: id,
            doctorVisitId: dto.doctorVisitId,
            issuedAt: dto.issuedAt?.asIssuedAtDate,
            note: dto.note,
            createdAt: createdAt,
            items: items
        )
    }
}

extension PrescriptionItem {
    static func from(_ dto: Components.Schemas.PrescriptionItemResponse) throws -> PrescriptionItem {
        guard let id = dto.id else { throw APIError.decoding }
        guard let prescriptionId = dto.prescriptionId else { throw APIError.decoding }
        guard let medicationName = dto.medicationName else { throw APIError.decoding }
        return PrescriptionItem(
            id: id,
            prescriptionId: prescriptionId,
            medicationName: medicationName,
            dosageText: dto.dosageText,
            instructions: dto.instructions,
            durationDays: dto.durationDays
        )
    }
}
