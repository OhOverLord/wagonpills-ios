import Foundation

struct PrescriptionCreateRequest: Sendable {
    var doctorVisitId: Int64?
    var issuedAt: Date?
    var note: String?
}

struct PrescriptionUpdateRequest: Sendable {
    var issuedAt: Date?
    var note: String?
}

struct PrescriptionItemCreateRequest: Sendable {
    var medicationName: String
    var dosageText: String?
    var instructions: String?
    var durationDays: Int32?
}

struct PrescriptionItemUpdateRequest: Sendable {
    var medicationName: String?
    var dosageText: String?
    var instructions: String?
    var durationDays: Int32?
}

// MARK: - DTO mapping

extension PrescriptionCreateRequest {
    func toDTO() -> Components.Schemas.CreatePrescriptionRequest {
        Components.Schemas.CreatePrescriptionRequest(
            doctorVisitId: doctorVisitId,
            issuedAt: issuedAt?.asIssuedAtString,
            note: note
        )
    }
}

extension PrescriptionUpdateRequest {
    func toDTO() -> Components.Schemas.UpdatePrescriptionRequest {
        Components.Schemas.UpdatePrescriptionRequest(
            issuedAt: issuedAt?.asIssuedAtString,
            note: note
        )
    }
}

extension PrescriptionItemCreateRequest {
    func toDTO() -> Components.Schemas.CreatePrescriptionItemRequest {
        Components.Schemas.CreatePrescriptionItemRequest(
            medicationName: medicationName,
            dosageText: dosageText,
            instructions: instructions,
            durationDays: durationDays
        )
    }
}

extension PrescriptionItemUpdateRequest {
    func toDTO() -> Components.Schemas.UpdatePrescriptionItemRequest {
        Components.Schemas.UpdatePrescriptionItemRequest(
            medicationName: medicationName,
            dosageText: dosageText,
            instructions: instructions,
            durationDays: durationDays
        )
    }
}
