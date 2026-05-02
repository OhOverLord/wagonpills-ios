import Foundation

struct Medication: Identifiable, Equatable, Hashable, Sendable, Codable {
    let id: Int64
    let name: String
    let dosageText: String?
    let instructions: String?
    let startDate: Date
    let endDate: Date?
    let isActive: Bool
    let stockUnit: StockUnit
    let doseQuantity: Double?
    let currentStock: Double?
    let lowStockThreshold: Double?
    let catalogItemId: Int64?
    let regionCode: String?
    let createdAt: Date
    let updatedAt: Date
}

enum StockUnit: String, Equatable, Sendable, Codable {
    case tablet      = "TABLET"
    case capsule     = "CAPSULE"
    case milliliters = "ML"
    case drops       = "DROPS"

    var displayName: String {
        switch self {
        case .tablet:      return String(localized: "Tablet")
        case .capsule:     return String(localized: "Capsule")
        case .milliliters: return String(localized: "mL")
        case .drops:       return String(localized: "Drops")
        }
    }
}

// MARK: - DTO mapping

extension Medication {
    static func from(_ dto: Components.Schemas.MedicationResponse) throws -> Medication {
        guard let id = dto.id else { throw APIError.decoding }
        guard let name = dto.name else { throw APIError.decoding }
        guard let active = dto.active else { throw APIError.decoding }
        guard let createdAt = dto.createdAt else { throw APIError.decoding }
        guard let updatedAt = dto.updatedAt else { throw APIError.decoding }
        guard let rawUnit = dto.stockUnit else { throw APIError.decoding }
        guard let stockUnit = StockUnit(rawValue: rawUnit.rawValue) else { throw APIError.decoding }
        guard let startDateStr = dto.startDate else { throw APIError.decoding }
        guard let startDate = Self.dateOnlyFormatter.date(from: startDateStr) else { throw APIError.decoding }

        let endDate = try parseOptionalDate(dto.endDate)

        return Medication(
            id: id,
            name: name,
            dosageText: dto.dosageText,
            instructions: dto.instructions,
            startDate: startDate,
            endDate: endDate,
            isActive: active,
            stockUnit: stockUnit,
            doseQuantity: dto.doseQuantity,
            currentStock: dto.currentStock,
            lowStockThreshold: dto.lowStockThreshold,
            catalogItemId: dto.catalogItemId,
            regionCode: dto.regionCode,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func parseOptionalDate(_ string: String?) throws -> Date? {
        guard let string else { return nil }
        guard let date = Self.dateOnlyFormatter.date(from: string) else { throw APIError.decoding }
        return date
    }

    private static let dateOnlyFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
