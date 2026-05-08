import Foundation
import Observation

// MARK: - Catalog suggestion controller

@MainActor
@Observable
final class CatalogSuggestionController {
    var suggestions: [CatalogItem] = []
    var isSearching: Bool = false
    var isVisible: Bool = false

    private var task: Task<Void, Never>?
    private var suppressNextSearch: Bool = false
    private let repository: any CatalogRepository

    init(repository: any CatalogRepository) {
        self.repository = repository
    }

    func onNameChanged(_ text: String, regionCode: String) {
        if suppressNextSearch {
            suppressNextSearch = false
            return
        }
        task?.cancel()
        task = nil
        guard text.count >= 2 else {
            suggestions = []
            isVisible = false
            isSearching = false
            return
        }
        isSearching = true
        let currentText = text
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(300))
                let results = try await repository.search(name: currentText, regionCode: regionCode)
                self.suggestions = results
                self.isSearching = false
                self.isVisible = true
            } catch {
                if !Task.isCancelled {
                    self.suggestions = []
                    self.isSearching = false
                    self.isVisible = false
                }
            }
        }
    }

    func select(_ item: CatalogItem) -> CatalogItem {
        task?.cancel()
        task = nil
        suggestions = []
        isSearching = false
        isVisible = false
        suppressNextSearch = true
        return item
    }

    func dismiss() {
        task?.cancel()
        task = nil
        suggestions = []
        isSearching = false
        isVisible = false
    }
}

// MARK: - ViewModel

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

    var name: String = "" {
        didSet {
            if case .create = mode {
                suggestions.onNameChanged(name, regionCode: preferredRegionCode)
            }
        }
    }
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
    let suggestions: CatalogSuggestionController

    private let repository: any MedicationRepository

    private var preferredRegionCode: String {
        UserDefaults.standard.string(forKey: "preferredRegionCode") ?? "CZ"
    }

    init(mode: Mode, repository: any MedicationRepository, catalogRepository: any CatalogRepository) {
        self.mode = mode
        self.repository = repository
        self.suggestions = CatalogSuggestionController(repository: catalogRepository)

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
        dosageText = item.strength ?? ""
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
