import Foundation

struct VisitCreateRequest: Sendable {
    var doctorName: String?
    var specialty: String?
    var visitAt: Date
    var location: String?
    var diagnosis: String?
    var recommendations: String?
}

struct VisitUpdateRequest: Sendable {
    var doctorName: String?
    var specialty: String?
    var visitAt: Date?
    var location: String?
    var diagnosis: String?
    var recommendations: String?
}

// MARK: - DTO mapping

extension VisitCreateRequest {
    func toDTO() -> Components.Schemas.CreateDoctorVisitRequest {
        Components.Schemas.CreateDoctorVisitRequest(
            doctorName: doctorName,
            specialty: specialty,
            visitAt: visitAt,
            location: location,
            diagnosis: diagnosis,
            recommendations: recommendations
        )
    }
}

extension VisitUpdateRequest {
    func toDTO() -> Components.Schemas.UpdateDoctorVisitRequest {
        Components.Schemas.UpdateDoctorVisitRequest(
            doctorName: doctorName,
            specialty: specialty,
            visitAt: visitAt,
            location: location,
            diagnosis: diagnosis,
            recommendations: recommendations
        )
    }
}
