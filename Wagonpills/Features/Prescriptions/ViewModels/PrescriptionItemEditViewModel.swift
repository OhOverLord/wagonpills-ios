import Foundation
import Observation

@MainActor
@Observable
final class PrescriptionItemEditViewModel {
    enum Mode {
        case create(prescriptionId: Int64)
        case edit(PrescriptionItem)
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(APIError)
    }

    var medicationName: String = ""
    var dosageText: String = ""
    var instructions: String = ""
    var durationDaysText: String = ""

    private(set) var saveState: SaveState = .idle

    var isSaveDisabled: Bool { medicationName.trimmingCharacters(in: .whitespaces).isEmpty }

    let mode: Mode
    private let repository: any PrescriptionRepository

    init(mode: Mode, repository: any PrescriptionRepository) {
        self.mode = mode
        self.repository = repository

        if case .edit(let item) = mode {
            medicationName = item.medicationName
            dosageText = item.dosageText ?? ""
            instructions = item.instructions ?? ""
            durationDaysText = item.durationDays.map { String($0) } ?? ""
        }
    }

    func save() async {
        let trimmedName = medicationName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            saveState = .failed(.validation(message: String(localized: "Medication name is required.")))
            return
        }

        saveState = .saving
        let parsedDays = Int32(durationDaysText)

        do {
            switch mode {
            case .create(let prescriptionId):
                let request = PrescriptionItemCreateRequest(
                    medicationName: trimmedName,
                    dosageText: dosageText.nilIfEmpty,
                    instructions: instructions.nilIfEmpty,
                    durationDays: parsedDays
                )
                _ = try await repository.createItem(prescriptionId: prescriptionId, request)
            case .edit(let item):
                let request = PrescriptionItemUpdateRequest(
                    medicationName: trimmedName,
                    dosageText: dosageText.nilIfEmpty,
                    instructions: instructions.nilIfEmpty,
                    durationDays: parsedDays
                )
                _ = try await repository.updateItem(
                    prescriptionId: item.prescriptionId,
                    itemId: item.id,
                    request
                )
            }
            saveState = .saved
        } catch let error as APIError {
            saveState = .failed(error)
        } catch {
            saveState = .failed(APIError.from(error))
        }
    }
}

extension PrescriptionItemEditViewModel.Mode {
    var navigationTitle: String {
        switch self {
        case .create: return String(localized: "Add Item")
        case .edit:   return String(localized: "Edit Item")
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
