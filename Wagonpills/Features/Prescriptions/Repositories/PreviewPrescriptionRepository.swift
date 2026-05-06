#if DEBUG
import Foundation

@MainActor
final class PreviewPrescriptionRepository: PrescriptionRepository {
    private var prescriptions: [Prescription]
    var error: APIError?

    init(
        prescriptions: [Prescription] = PreviewPrescriptionRepository.makeSamplePrescriptions(),
        error: APIError? = nil
    ) {
        self.prescriptions = prescriptions
        self.error = error
    }

    func fetchAll() async throws -> [Prescription] {
        if let error { throw error }
        return prescriptions
    }

    func fetchById(_ id: Int64) async throws -> Prescription {
        if let error { throw error }
        guard let prescription = prescriptions.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return prescription
    }

    func create(_ request: PrescriptionCreateRequest) async throws -> Prescription {
        if let error { throw error }
        let prescription = Prescription(
            id: Int64.random(in: 100...9_999),
            doctorVisitId: request.doctorVisitId,
            issuedAt: request.issuedAt,
            note: request.note,
            createdAt: Date(),
            items: []
        )
        prescriptions.append(prescription)
        return prescription
    }

    func update(id: Int64, _ request: PrescriptionUpdateRequest) async throws -> Prescription {
        if let error { throw error }
        guard let index = prescriptions.firstIndex(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        var updated = prescriptions[index]
        if let issuedAt = request.issuedAt { updated.issuedAt = issuedAt }
        if let note = request.note { updated.note = note }
        prescriptions[index] = updated
        return updated
    }

    func delete(id: Int64) async throws {
        if let error { throw error }
        prescriptions.removeAll { $0.id == id }
    }

    func fetchItems(prescriptionId: Int64) async throws -> [PrescriptionItem] {
        if let error { throw error }
        return prescriptions.first(where: { $0.id == prescriptionId })?.items ?? []
    }

    func createItem(
        prescriptionId: Int64,
        _ request: PrescriptionItemCreateRequest
    ) async throws -> PrescriptionItem {
        if let error { throw error }
        let item = PrescriptionItem(
            id: Int64.random(in: 100...9_999),
            prescriptionId: prescriptionId,
            medicationName: request.medicationName,
            dosageText: request.dosageText,
            instructions: request.instructions,
            durationDays: request.durationDays
        )
        if let index = prescriptions.firstIndex(where: { $0.id == prescriptionId }) {
            prescriptions[index].items.append(item)
        }
        return item
    }

    func updateItem(
        prescriptionId: Int64,
        itemId: Int64,
        _ request: PrescriptionItemUpdateRequest
    ) async throws -> PrescriptionItem {
        if let error { throw error }
        guard let prescriptionIndex = prescriptions.firstIndex(where: { $0.id == prescriptionId }),
              let itemIndex = prescriptions[prescriptionIndex].items.firstIndex(where: { $0.id == itemId })
        else {
            throw APIError.notFound
        }
        var updated = prescriptions[prescriptionIndex].items[itemIndex]
        if let name = request.medicationName { updated.medicationName = name }
        if let dosage = request.dosageText { updated.dosageText = dosage }
        if let instructions = request.instructions { updated.instructions = instructions }
        if let days = request.durationDays { updated.durationDays = days }
        prescriptions[prescriptionIndex].items[itemIndex] = updated
        return updated
    }

    func deleteItem(prescriptionId: Int64, itemId: Int64) async throws {
        if let error { throw error }
        if let index = prescriptions.firstIndex(where: { $0.id == prescriptionId }) {
            prescriptions[index].items.removeAll { $0.id == itemId }
        }
    }

    nonisolated static func makeSamplePrescriptions() -> [Prescription] {
        let now = Date()
        let cal = Calendar.current
        return [
            Prescription(
                id: 1,
                doctorVisitId: 1,
                issuedAt: cal.date(byAdding: .day, value: -14, to: now),
                note: "Post-visit prescription",
                createdAt: cal.date(byAdding: .day, value: -14, to: now) ?? now,
                items: [
                    PrescriptionItem(
                        id: 1,
                        prescriptionId: 1,
                        medicationName: "Amoxicillin",
                        dosageText: "500 mg",
                        instructions: "Take with food",
                        durationDays: 7
                    ),
                    PrescriptionItem(
                        id: 2,
                        prescriptionId: 1,
                        medicationName: "Ibuprofen",
                        dosageText: "400 mg",
                        instructions: "As needed for pain",
                        durationDays: nil
                    )
                ]
            ),
            Prescription(
                id: 2,
                doctorVisitId: nil,
                issuedAt: cal.date(byAdding: .month, value: -1, to: now),
                note: nil,
                createdAt: cal.date(byAdding: .month, value: -1, to: now) ?? now,
                items: []
            )
        ]
    }
}
#endif
