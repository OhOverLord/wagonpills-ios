import Foundation
import Observation

@MainActor
@Observable
final class MedicationChangesViewModel {
    enum ListState: Equatable {
        case idle
        case loading
        case loaded([MedicationChange])
        case failed(APIError)
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(APIError)
    }

    private(set) var listState: ListState = .idle
    private(set) var saveState: SaveState = .idle

    var changeType: MedicationChangeType = .dosageChange
    var oldValue: String = ""
    var newValue: String = ""
    var reason: String = ""
    var doctorVisitId: Int64?

    private let medicationId: Int64
    private let repository: any MedicationRepository

    init(medicationId: Int64, repository: any MedicationRepository) {
        self.medicationId = medicationId
        self.repository = repository
    }

    func load() async {
        if case .loaded = listState { /* keep data visible during refresh */ } else {
            listState = .loading
        }
        do {
            let changes = try await repository.fetchChanges(medicationId: medicationId)
            listState = .loaded(changes.sorted { $0.changedAt > $1.changedAt })
        } catch let error as APIError {
            listState = .failed(error)
        } catch {
            listState = .failed(APIError.from(error))
        }
    }

    func createChange() async {
        saveState = .saving
        let request = MedicationChangeCreateRequest(
            changeType: changeType,
            doctorVisitId: doctorVisitId,
            oldValue: oldValue.isEmpty ? nil : oldValue,
            newValue: newValue.isEmpty ? nil : newValue,
            reason: reason.isEmpty ? nil : reason
        )
        do {
            _ = try await repository.createChange(medicationId: medicationId, request)
            try await applyChangeToMedication(changeType: changeType, newValue: newValue.isEmpty ? nil : newValue)
            saveState = .saved
            await load()
        } catch let error as APIError {
            saveState = .failed(error)
        } catch {
            saveState = .failed(APIError.from(error))
        }
    }

    private func applyChangeToMedication(changeType: MedicationChangeType, newValue: String?) async throws {
        let medication = try await repository.fetchById(medicationId)
        let updateRequest = MedicationUpdateRequest(
            name: medication.name,
            dosageText: changeType == .dosageChange ? newValue : medication.dosageText,
            instructions: medication.instructions,
            startDate: medication.startDate,
            endDate: medication.endDate,
            isActive: activeValue(for: changeType, current: medication.isActive),
            stockUnit: medication.stockUnit,
            doseQuantity: medication.doseQuantity,
            lowStockThreshold: medication.lowStockThreshold
        )
        _ = try await repository.update(id: medicationId, updateRequest)
    }

    private func activeValue(for changeType: MedicationChangeType, current: Bool) -> Bool {
        switch changeType {
        case .start:          return true
        case .stop:           return false
        case .dosageChange, .scheduleChange: return current
        }
    }

    func resetForm() {
        changeType = .dosageChange
        oldValue = ""
        newValue = ""
        reason = ""
        doctorVisitId = nil
        saveState = .idle
    }
}
