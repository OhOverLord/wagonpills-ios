import Foundation
import Testing
@testable import Wagonpills

@Suite("MedicationMapping")
struct MedicationMappingTests {
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func makeFullDTO() -> Components.Schemas.MedicationResponse {
        Components.Schemas.MedicationResponse(
            id: 1,
            name: "Metformin",
            dosageText: "500 mg",
            instructions: "Take after meals",
            startDate: "2026-01-01",
            endDate: "2026-06-01",
            active: true,
            stockUnit: .tablet,
            doseQuantity: 2,
            lowStockThreshold: 5,
            catalogItemId: 42,
            regionCode: "CZ",
            createdAt: Self.iso8601.date(from: "2025-12-01T10:00:00Z"),
            updatedAt: Self.iso8601.date(from: "2026-01-01T08:00:00Z"),
            currentStock: 30
        )
    }

    @Test("happy path — all fields populated")
    func happyPathAllFields() throws {
        let med = try Medication.from(makeFullDTO())
        #expect(med.id == 1)
        #expect(med.name == "Metformin")
        #expect(med.dosageText == "500 mg")
        #expect(med.instructions == "Take after meals")
        #expect(med.isActive == true)
        #expect(med.stockUnit == .tablet)
        #expect(med.doseQuantity == 2)
        #expect(med.currentStock == 30)
        #expect(med.lowStockThreshold == 5)
        #expect(med.catalogItemId == 42)
        #expect(med.regionCode == "CZ")
        #expect(med.endDate != nil)
    }

    @Test("nil endDate maps to nil")
    func nilEndDate() throws {
        var dto = makeFullDTO()
        dto.endDate = nil
        let med = try Medication.from(dto)
        #expect(med.endDate == nil)
    }

    @Test("nil optional fields (dosageText, instructions, currentStock) map without crash")
    func nilOptionals() throws {
        var dto = makeFullDTO()
        dto.dosageText = nil
        dto.instructions = nil
        dto.currentStock = nil
        dto.lowStockThreshold = nil
        dto.doseQuantity = nil
        dto.catalogItemId = nil
        dto.regionCode = nil
        let med = try Medication.from(dto)
        #expect(med.dosageText == nil)
        #expect(med.instructions == nil)
        #expect(med.currentStock == nil)
    }

    @Test("nil stockUnit throws .decoding")
    func nilStockUnit() {
        var dto = makeFullDTO()
        dto.stockUnit = nil
        #expect(throws: APIError.decoding) { try Medication.from(dto) }
    }

    @Test("nil startDate throws .decoding")
    func nilStartDate() {
        var dto = makeFullDTO()
        dto.startDate = nil
        #expect(throws: APIError.decoding) { try Medication.from(dto) }
    }

    @Test("invalid startDate string throws .decoding")
    func invalidStartDate() {
        var dto = makeFullDTO()
        dto.startDate = "not-a-date"
        #expect(throws: APIError.decoding) { try Medication.from(dto) }
    }

    @Test("nil id throws .decoding")
    func nilId() {
        var dto = makeFullDTO()
        dto.id = nil
        #expect(throws: APIError.decoding) { try Medication.from(dto) }
    }

    @Test("nil name throws .decoding")
    func nilName() {
        var dto = makeFullDTO()
        dto.name = nil
        #expect(throws: APIError.decoding) { try Medication.from(dto) }
    }
}
