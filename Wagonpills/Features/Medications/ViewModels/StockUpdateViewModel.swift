import Foundation
import Observation

@MainActor
@Observable
final class StockUpdateViewModel {
    enum Operation {
        case add
        case adjust
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(APIError)
    }

    var operation: Operation = .add
    var quantityText: String = ""
    var note: String = ""
    private(set) var saveState: SaveState = .idle

    private let medicationId: Int64
    private let repository: any MedicationRepository

    init(medicationId: Int64, repository: any MedicationRepository) {
        self.medicationId = medicationId
        self.repository = repository
    }

    func save() async {
        guard let quantity = Double(quantityText), quantity != 0 else {
            saveState = .failed(.validation(message: String(localized: "Enter a valid quantity.")))
            return
        }

        saveState = .saving
        do {
            switch operation {
            case .add:
                guard quantity > 0 else {
                    saveState = .failed(.validation(message: String(localized: "Quantity to add must be positive.")))
                    return
                }
                try await repository.addStock(
                    medicationId: medicationId,
                    quantity: quantity,
                    note: note.isEmpty ? nil : note
                )
            case .adjust:
                try await repository.adjustStock(
                    medicationId: medicationId,
                    quantity: quantity,
                    note: note.isEmpty ? nil : note
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
