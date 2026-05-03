import Foundation
import Observation

@MainActor
@Observable
final class MedicationEditViewModel {
    enum Mode {
        case create
        case edit(Medication)
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(APIError)
    }

    var name: String = ""
    var dosageText: String = ""
    var instructions: String = ""
    var startDate: Date = .now
    var endDate: Date?
    var hasEndDate: Bool = false
    var isActive: Bool = true
    var stockUnit: StockUnit = .tablet
    var doseQuantity: String = ""
    var currentStock: String = ""
    var lowStockThreshold: String = ""
    private(set) var catalogItemId: Int64?

    private(set) var saveState: SaveState = .idle
    private(set) var isDeleting: Bool = false
    var deleteError: APIError?

    let mode: Mode
    private let repository: any MedicationRepository

    init(mode: Mode, repository: any MedicationRepository) {
        self.mode = mode
        self.repository = repository

        if case .edit(let med) = mode {
            name = med.name
            dosageText = med.dosageText ?? ""
            instructions = med.instructions ?? ""
            startDate = med.startDate
            if let end = med.endDate {
                endDate = end
                hasEndDate = true
            }
            isActive = med.isActive
            stockUnit = med.stockUnit
            if let qty = med.doseQuantity {
                doseQuantity = "\(qty)"
            }
            if let threshold = med.lowStockThreshold {
                lowStockThreshold = "\(threshold)"
            }
        }
    }

    func save() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            saveState = .failed(.validation(message: String(localized: "Name is required.")))
            return
        }

        saveState = .saving
        do {
            switch mode {
            case .create:
                let request = MedicationCreateRequest(
                    name: name.trimmingCharacters(in: .whitespaces),
                    dosageText: dosageText.isEmpty ? nil : dosageText,
                    instructions: instructions.isEmpty ? nil : instructions,
                    startDate: startDate,
                    endDate: hasEndDate ? endDate : nil,
                    stockUnit: stockUnit,
                    doseQuantity: Double(doseQuantity),
                    lowStockThreshold: Double(lowStockThreshold),
                    currentStock: Double(currentStock),
                    catalogItemId: catalogItemId
                )
                _ = try await repository.create(request)
            case .edit(let med):
                let request = MedicationUpdateRequest(
                    name: name.trimmingCharacters(in: .whitespaces),
                    dosageText: dosageText.isEmpty ? nil : dosageText,
                    instructions: instructions.isEmpty ? nil : instructions,
                    startDate: startDate,
                    endDate: hasEndDate ? endDate : nil,
                    isActive: isActive,
                    stockUnit: stockUnit,
                    doseQuantity: Double(doseQuantity),
                    lowStockThreshold: Double(lowStockThreshold)
                )
                _ = try await repository.update(id: med.id, request)
            }
            saveState = .saved
        } catch let error as APIError {
            saveState = .failed(error)
        } catch {
            saveState = .failed(APIError.from(error))
        }
    }

    func delete() async {
        guard case .edit(let med) = mode else { return }
        isDeleting = true
        deleteError = nil
        do {
            try await repository.delete(id: med.id)
            saveState = .saved
        } catch let error as APIError {
            deleteError = error
            isDeleting = false
        } catch {
            deleteError = APIError.from(error)
            isDeleting = false
        }
        isDeleting = false
    }
}

// MARK: - Catalog prefill

extension MedicationEditViewModel {
    func prefillFromCatalog(_ item: CatalogItem) {
        name = item.name
        if let strength = item.strength, dosageText.isEmpty {
            dosageText = strength
        }
        catalogItemId = item.id
    }
}

extension MedicationEditViewModel.Mode {
    var navigationTitle: String {
        switch self {
        case .create: return String(localized: "New Medication")
        case .edit:   return String(localized: "Edit Medication")
        }
    }
}
