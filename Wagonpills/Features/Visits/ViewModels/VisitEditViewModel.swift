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
    private let calendarRepository: (any CalendarRepository)?

    init(mode: Mode, repository: any VisitRepository, calendarRepository: (any CalendarRepository)? = nil) {
        self.mode = mode
        self.repository = repository
        self.calendarRepository = calendarRepository

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
                let visit = try await repository.create(request)
                if let calendarRepo = calendarRepository {
                    let eventTitle = doctorName.nilIfEmpty ?? String(localized: "Doctor Visit")
                    let calendarRequest = CalendarEventCreateRequest(
                        type: .doctorVisit,
                        title: eventTitle,
                        description: nil,
                        location: location.nilIfEmpty,
                        startsAt: visitAt,
                        endsAt: nil,
                        timezone: nil,
                        doctorVisitId: visit.id
                    )
                    _ = try? await calendarRepo.create(calendarRequest)
                }
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
