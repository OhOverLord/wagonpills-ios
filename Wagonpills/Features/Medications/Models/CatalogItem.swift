import Foundation

struct CatalogItem: Identifiable, Equatable, Sendable, Codable {
    let id: Int64
    let name: String
    let strength: String?
    let form: String?
    let regionCode: String
    let aliases: [String]
}

// MARK: - DTO mapping

extension CatalogItem {
    static func from(_ dto: Components.Schemas.CatalogItemResponse) throws -> CatalogItem {
        guard let id = dto.id else { throw APIError.decoding }
        guard let name = dto.name else { throw APIError.decoding }
        guard let regionCode = dto.regionCode else { throw APIError.decoding }
        return CatalogItem(
            id: id,
            name: name,
            strength: dto.strength,
            form: dto.form,
            regionCode: regionCode,
            aliases: dto.aliases ?? []
        )
    }
}
