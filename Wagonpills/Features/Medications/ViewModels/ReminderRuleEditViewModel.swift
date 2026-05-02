import Foundation
import Observation
import SwiftUI

// Represents a time entry in the edit form — may reference an existing server-side
// time (has an id) or be pending creation (no id yet).
struct TimeDraft: Identifiable, Equatable {
    let id: UUID
    let existingId: Int64?
    let hour: Int
    let minute: Int

    var displayString: String { String(format: "%02d:%02d", hour, minute) }

    var dateComponents: DateComponents {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return comps
    }

    init(from existing: ReminderTime) {
        id = UUID()
        existingId = existing.id
        hour = existing.hour
        minute = existing.minute
    }

    init(hour: Int, minute: Int) {
        id = UUID()
        existingId = nil
        self.hour = hour
        self.minute = minute
    }
}

@MainActor
@Observable
final class ReminderRuleEditViewModel {
    enum Mode {
        case create
        case edit(ReminderRule)
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(APIError)
    }

    var repeatType: RepeatType = .daily
    var intervalDaysText: String = "1"
    var selectedDays: Set<Weekday> = []
    var times: [TimeDraft] = []
    var validationError: String?

    private(set) var saveState: SaveState = .idle
    private(set) var isDeleting: Bool = false
    var deleteError: APIError?

    let mode: Mode
    let medicationId: Int64
    private let repository: any ReminderRepository

    // IDs of server-side times that existed when the form opened.
    private var originalTimeIds: Set<Int64> = []

    init(mode: Mode, medicationId: Int64, repository: any ReminderRepository) {
        self.mode = mode
        self.medicationId = medicationId
        self.repository = repository

        if case .edit(let rule) = mode {
            repeatType = rule.repeatType
            intervalDaysText = rule.intervalDays.map(String.init) ?? "1"
            selectedDays = rule.daysOfWeek
            times = rule.times.map(TimeDraft.init(from:))
            originalTimeIds = Set(rule.times.map(\.id))
        }
    }

    func addTime(_ components: DateComponents) {
        let draft = TimeDraft(hour: components.hour ?? 0, minute: components.minute ?? 0)
        times.append(draft)
    }

    func removeTime(at offsets: IndexSet) {
        times.remove(atOffsets: offsets)
    }

    func save() async {
        guard validate() else { return }
        saveState = .saving

        do {
            switch mode {
            case .create:
                try await saveCreate()
            case .edit(let rule):
                try await saveEdit(ruleId: rule.id)
            }
            saveState = .saved
        } catch let error as APIError {
            saveState = .failed(error)
        } catch {
            saveState = .failed(APIError.from(error))
        }
    }

    func delete() async {
        guard case .edit(let rule) = mode else { return }
        isDeleting = true
        deleteError = nil
        do {
            try await repository.deleteRule(medicationId: medicationId, ruleId: rule.id)
            saveState = .saved
        } catch let error as APIError {
            deleteError = error
        } catch {
            deleteError = APIError.from(error)
        }
        isDeleting = false
    }

    // MARK: - Private

    private func validate() -> Bool {
        validationError = nil
        if repeatType == .interval {
            guard let days = Int(intervalDaysText), days >= 1 else {
                validationError = String(localized: "Interval must be a whole number of 1 or more days.")
                return false
            }
        }
        if repeatType == .weekly && selectedDays.isEmpty {
            validationError = String(localized: "Select at least one day of the week.")
            return false
        }
        if times.isEmpty {
            validationError = String(localized: "Add at least one reminder time.")
            return false
        }
        return true
    }

    private var intervalDays: Int? {
        repeatType == .interval ? Int(intervalDaysText) : nil
    }

    private var effectiveDays: Set<Weekday> {
        repeatType == .weekly ? selectedDays : []
    }

    private func saveCreate() async throws {
        let request = ReminderRuleCreateRequest(
            repeatType: repeatType,
            intervalDays: intervalDays,
            daysOfWeek: effectiveDays
        )
        let rule = try await repository.createRule(medicationId: medicationId, request)
        for draft in times {
            _ = try await repository.addTime(medicationId: medicationId, ruleId: rule.id, time: draft.dateComponents)
        }
    }

    private func saveEdit(ruleId: Int64) async throws {
        let request = ReminderRuleUpdateRequest(
            repeatType: repeatType,
            intervalDays: intervalDays,
            daysOfWeek: effectiveDays,
            active: true
        )
        _ = try await repository.updateRule(medicationId: medicationId, ruleId: ruleId, request)

        let keptIds = Set(times.compactMap(\.existingId))
        let toDelete = originalTimeIds.subtracting(keptIds)
        for timeId in toDelete {
            try await repository.deleteTime(medicationId: medicationId, ruleId: ruleId, timeId: timeId)
        }
        for draft in times where draft.existingId == nil {
            _ = try await repository.addTime(medicationId: medicationId, ruleId: ruleId, time: draft.dateComponents)
        }
    }
}

extension ReminderRuleEditViewModel.Mode {
    var navigationTitle: String {
        switch self {
        case .create: return String(localized: "New Reminder Rule")
        case .edit:   return String(localized: "Edit Reminder Rule")
        }
    }
}
