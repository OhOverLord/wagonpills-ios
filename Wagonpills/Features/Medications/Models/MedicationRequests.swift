import Foundation

struct MedicationChangeCreateRequest: Sendable {
    var changeType: MedicationChangeType
    var doctorVisitId: Int64?
    var oldValue: String?
    var newValue: String?
    var reason: String?
}

struct MedicationCreateRequest {
    let name: String
    let dosageText: String?
    let instructions: String?
    let startDate: Date
    let endDate: Date?
    let stockUnit: StockUnit
    let doseQuantity: Double?
    let lowStockThreshold: Double?
    let currentStock: Double?
    let catalogItemId: Int64?
}

struct MedicationUpdateRequest {
    let name: String
    let dosageText: String?
    let instructions: String?
    let startDate: Date
    let endDate: Date?
    let isActive: Bool
    let stockUnit: StockUnit
    let doseQuantity: Double?
    let lowStockThreshold: Double?
}

// MARK: - DTO mapping

extension MedicationCreateRequest {
    func toDTO() -> Components.Schemas.CreateMedicationRequest {
        Components.Schemas.CreateMedicationRequest(
            name: name,
            dosageText: dosageText,
            instructions: instructions,
            startDate: Self.dateFormatter.string(from: startDate),
            endDate: endDate.map { Self.dateFormatter.string(from: $0) },
            stockUnit: .init(rawValue: stockUnit.rawValue) ?? .tablet,
            doseQuantity: doseQuantity,
            lowStockThreshold: lowStockThreshold,
            catalogItemId: catalogItemId,
            currentStock: currentStock
        )
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}

extension MedicationUpdateRequest {
    func toDTO() -> Components.Schemas.UpdateMedicationRequest {
        Components.Schemas.UpdateMedicationRequest(
            name: name,
            dosageText: dosageText,
            instructions: instructions,
            startDate: Self.dateFormatter.string(from: startDate),
            endDate: endDate.map { Self.dateFormatter.string(from: $0) },
            active: isActive,
            stockUnit: .init(rawValue: stockUnit.rawValue),
            doseQuantity: doseQuantity,
            lowStockThreshold: lowStockThreshold
        )
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
