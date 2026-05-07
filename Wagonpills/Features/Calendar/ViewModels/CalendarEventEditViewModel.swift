import Foundation
import Observation

@MainActor
@Observable
final class CalendarEventEditViewModel {
    enum Mode {
        case create
        case edit(CalendarEvent)
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(APIError)
    }

    var type: CalendarEventType = .other
    var title: String = ""
    var description: String = ""
    var location: String = ""
    var doctorName: String = ""
    var startsAt: Date = .now
    var endsAt: Date = Date().addingTimeInterval(3600)
    var hasEndDate: Bool = false
    var timezone: String = "Europe/Prague"

    private(set) var saveState: SaveState = .idle

    let mode: Mode
    let repository: any CalendarRepository
    let visitRepository: (any VisitRepository)?

    init(
        mode: Mode,
        repository: any CalendarRepository,
        visitRepository: (any VisitRepository)? = nil,
        initialDate: Date? = nil
    ) {
        self.mode = mode
        self.repository = repository
        self.visitRepository = visitRepository

        if let date = initialDate, case .create = mode {
            startsAt = date
            endsAt = date.addingTimeInterval(3600)
        }

        if case .edit(let event) = mode {
            type = event.type
            title = event.title
            description = event.description ?? ""
            location = event.location ?? ""
            startsAt = event.startsAt
            if let end = event.endsAt {
                endsAt = end
                hasEndDate = true
            }
            timezone = event.timezone ?? "Europe/Prague"
        }
    }

    var navigationTitle: String {
        switch mode {
        case .create: return String(localized: "New Event")
        case .edit: return String(localized: "Edit Event")
        }
    }

    var isTitleValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    func save() async {
        guard isTitleValid else { return }
        saveState = .saving
        do {
            switch mode {
            case .create:
                var linkedVisitId: Int64?
                if type == .doctorVisit, let visitRepo = visitRepository {
                    let visitRequest = VisitCreateRequest(
                        doctorName: doctorName.nilIfEmpty,
                        visitAt: startsAt,
                        location: location.nilIfEmpty
                    )
                    let visit = try await visitRepo.create(visitRequest)
                    linkedVisitId = visit.id
                }
                let request = CalendarEventCreateRequest(
                    type: type,
                    title: title,
                    description: description.nilIfEmpty,
                    location: location.nilIfEmpty,
                    startsAt: startsAt,
                    endsAt: hasEndDate ? endsAt : nil,
                    timezone: timezone,
                    doctorVisitId: linkedVisitId
                )
                _ = try await repository.create(request)
            case .edit(let event):
                let request = CalendarEventUpdateRequest(
                    type: type,
                    title: title,
                    description: description.nilIfEmpty,
                    location: location.nilIfEmpty,
                    startsAt: startsAt,
                    endsAt: hasEndDate ? endsAt : nil,
                    timezone: timezone,
                    isCancelled: event.isCancelled
                )
                _ = try await repository.update(id: event.id, request)
            }
            saveState = .saved
        } catch let error as APIError {
            saveState = .failed(error)
        } catch {
            saveState = .failed(APIError.from(error))
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
