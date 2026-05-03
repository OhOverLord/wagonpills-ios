import Foundation

struct StockSummary: Equatable, Sendable {
    let medicationId: Int64
    let medicationName: String
    let currentStock: Double
    let unit: StockUnit
    let lowStockThreshold: Double?
    let isLowStock: Bool
}

struct StockMovement: Identifiable, Equatable, Sendable {
    let id: Int64
    let medicationId: Int64
    let movementType: StockMovementType
    let quantity: Double
    let unit: StockUnit
    let relatedIntakeLogId: Int64?
    let note: String?
    let createdAt: Date
}

enum StockMovementType: String, Sendable {
    case add     = "ADD"
    case consume = "CONSUME"
    case adjust  = "ADJUST"

    var displayName: String {
        switch self {
        case .add:     return String(localized: "Refill")
        case .consume: return String(localized: "Taken")
        case .adjust:  return String(localized: "Adjustment")
        }
    }

    var systemImage: String {
        switch self {
        case .add:     return "plus.circle.fill"
        case .consume: return "checkmark.circle.fill"
        case .adjust:  return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - DTO mapping

extension StockSummary {
    static func from(_ dto: Components.Schemas.StockSummaryResponse) throws -> StockSummary {
        guard let medicationId = dto.medicationId else { throw APIError.decoding }
        guard let medicationName = dto.medicationName else { throw APIError.decoding }
        guard let currentStock = dto.currentStock else { throw APIError.decoding }
        guard let rawUnit = dto.unit else { throw APIError.decoding }
        guard let unit = StockUnit(rawValue: rawUnit.rawValue) else { throw APIError.decoding }
        guard let isLowStock = dto.lowStock else { throw APIError.decoding }

        return StockSummary(
            medicationId: medicationId,
            medicationName: medicationName,
            currentStock: currentStock,
            unit: unit,
            lowStockThreshold: dto.lowStockThreshold,
            isLowStock: isLowStock
        )
    }
}

extension StockMovement {
    static func from(_ dto: Components.Schemas.StockMovementResponse) throws -> StockMovement {
        guard let id = dto.id else { throw APIError.decoding }
        guard let medicationId = dto.medicationId else { throw APIError.decoding }
        guard let rawType = dto._type else { throw APIError.decoding }
        guard let movementType = StockMovementType(rawValue: rawType.rawValue) else { throw APIError.decoding }
        guard let quantity = dto.quantity else { throw APIError.decoding }
        guard let rawUnit = dto.unit else { throw APIError.decoding }
        guard let unit = StockUnit(rawValue: rawUnit.rawValue) else { throw APIError.decoding }
        guard let createdAt = dto.createdAt else { throw APIError.decoding }

        return StockMovement(
            id: id,
            medicationId: medicationId,
            movementType: movementType,
            quantity: quantity,
            unit: unit,
            relatedIntakeLogId: dto.relatedIntakeLogId,
            note: dto.note,
            createdAt: createdAt
        )
    }
}
