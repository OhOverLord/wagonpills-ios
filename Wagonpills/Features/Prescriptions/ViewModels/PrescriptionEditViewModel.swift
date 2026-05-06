import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class PrescriptionEditViewModel {
    enum Mode {
        case create
        case edit(Prescription)
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(APIError)
    }

    struct DraftItem: Identifiable, Equatable {
        let id: UUID
        var medicationName: String
        var dosageText: String?
        var instructions: String?
        var durationDays: Int32?

        init(medicationName: String, dosageText: String?, instructions: String?, durationDays: Int32?) {
            self.id = UUID()
            self.medicationName = medicationName
            self.dosageText = dosageText
            self.instructions = instructions
            self.durationDays = durationDays
        }

        func toCreateRequest() -> PrescriptionItemCreateRequest {
            PrescriptionItemCreateRequest(
                medicationName: medicationName,
                dosageText: dosageText,
                instructions: instructions,
                durationDays: durationDays
            )
        }
    }

    var doctorVisitId: Int64?
    var issuedAt: Date?
    var note: String = ""
    var pendingItems: [DraftItem] = []

    private(set) var saveState: SaveState = .idle

    let mode: Mode
    private let repository: any PrescriptionRepository

    init(mode: Mode, repository: any PrescriptionRepository) {
        self.mode = mode
        self.repository = repository

        if case .edit(let prescription) = mode {
            doctorVisitId = prescription.doctorVisitId
            issuedAt = prescription.issuedAt
            note = prescription.note ?? ""
        }
    }

    func addDraftItem(_ item: DraftItem) {
        pendingItems.append(item)
    }

    func removeDraftItems(at offsets: IndexSet) {
        pendingItems.remove(atOffsets: offsets)
    }

    func save() async {
        saveState = .saving
        do {
            switch mode {
            case .create:
                let request = PrescriptionCreateRequest(
                    doctorVisitId: doctorVisitId,
                    issuedAt: issuedAt,
                    note: note.nilIfEmpty
                )
                let created = try await repository.create(request)
                for item in pendingItems {
                    _ = try await repository.createItem(prescriptionId: created.id, item.toCreateRequest())
                }
            case .edit(let prescription):
                let request = PrescriptionUpdateRequest(
                    issuedAt: issuedAt,
                    note: note.nilIfEmpty
                )
                _ = try await repository.update(id: prescription.id, request)
            }
            saveState = .saved
        } catch let error as APIError {
            saveState = .failed(error)
        } catch {
            saveState = .failed(APIError.from(error))
        }
    }
}

extension PrescriptionEditViewModel.Mode {
    var navigationTitle: String {
        switch self {
        case .create: return String(localized: "New Prescription")
        case .edit:   return String(localized: "Edit Prescription")
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
