import Foundation
import Observation

@MainActor
@Observable
final class VisitEditViewModel {
    enum Mode {
        case create
        case edit(Visit)
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(APIError)
    }

    var doctorName: String = ""
    var specialty: String = ""
    var visitAt: Date = .now
    var location: String = ""
    var diagnosis: String = ""
    var recommendations: String = ""

    private(set) var saveState: SaveState = .idle

    let mode: Mode
    private let repository: any VisitRepository

    init(mode: Mode, repository: any VisitRepository) {
        self.mode = mode
        self.repository = repository

        if case .edit(let visit) = mode {
            doctorName = visit.doctorName ?? ""
            specialty = visit.specialty ?? ""
            visitAt = visit.visitAt
            location = visit.location ?? ""
            diagnosis = visit.diagnosis ?? ""
            recommendations = visit.recommendations ?? ""
        }
    }

    func save() async {
        saveState = .saving
        do {
            switch mode {
            case .create:
                let request = VisitCreateRequest(
                    doctorName: doctorName.nilIfEmpty,
                    specialty: specialty.nilIfEmpty,
                    visitAt: visitAt,
                    location: location.nilIfEmpty,
                    diagnosis: diagnosis.nilIfEmpty,
                    recommendations: recommendations.nilIfEmpty
                )
                _ = try await repository.create(request)
            case .edit(let visit):
                let request = VisitUpdateRequest(
                    doctorName: doctorName.nilIfEmpty,
                    specialty: specialty.nilIfEmpty,
                    visitAt: visitAt,
                    location: location.nilIfEmpty,
                    diagnosis: diagnosis.nilIfEmpty,
                    recommendations: recommendations.nilIfEmpty
                )
                _ = try await repository.update(id: visit.id, request)
            }
            saveState = .saved
        } catch let error as APIError {
            saveState = .failed(error)
        } catch {
            saveState = .failed(APIError.from(error))
        }
    }
}

extension VisitEditViewModel.Mode {
    var navigationTitle: String {
        switch self {
        case .create: return String(localized: "New Visit")
        case .edit:   return String(localized: "Edit Visit")
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
