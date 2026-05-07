import Foundation
import UserNotifications

protocol NotificationScheduler: Sendable {
    func requestPermission() async -> Bool
    func schedule(doses: [ScheduledDose]) async
    func cancelAll(medicationId: Int64) async
    func cancelAll()
    func scheduleEventReminder(_ reminder: EventReminder, for event: CalendarEvent) async throws
    func cancelEventReminder(id: Int64) async
}

actor LiveNotificationScheduler: NotificationScheduler {

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func schedule(doses: [ScheduledDose]) async {
        let center = UNUserNotificationCenter.current()

        // Cancel stale notifications for every medication in this batch.
        let affectedIds = Set(doses.map { $0.medicationId })
        let pending = await center.pendingNotificationRequests()
        let staleIds = pending
            .filter { req in affectedIds.contains { id in req.identifier.hasPrefix("dose.\(id).") } }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: staleIds)

        // iOS caps pending local notifications at 64 per app; take the nearest ones.
        for dose in doses.prefix(64) {
            let content = UNMutableNotificationContent()
            content.title = dose.medicationName
            content.body = String(localized: "Time to take your medication")
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dose.fireDate,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: notificationId(for: dose),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelAll(medicationId: Int64) async {
        let center = UNUserNotificationCenter.current()
        let prefix = "dose.\(medicationId)."
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .filter { $0.identifier.hasPrefix(prefix) }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    nonisolated func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func scheduleEventReminder(_ reminder: EventReminder, for event: CalendarEvent) async throws {
        guard reminder.channel == .push else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus != .denied else {
            throw APIError.unexpected("Notification permission denied")
        }

        guard let triggerDate = reminderTriggerDate(reminder: reminder, event: event) else { return }
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = reminderBody(reminder: reminder, event: event)
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "event-reminder-\(reminder.id)",
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    func cancelEventReminder(id: Int64) async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["event-reminder-\(id)"])
    }

    // MARK: - Helpers

    private func reminderTriggerDate(reminder: EventReminder, event: CalendarEvent) -> Date? {
        switch reminder.reminderType {
        case .beforeEvent:
            guard let minutes = reminder.minutesBefore else { return nil }
            return event.startsAt.addingTimeInterval(-Double(minutes) * 60)
        case .exactTime:
            return reminder.reminderAt
        }
    }

    private func reminderBody(reminder: EventReminder, event: CalendarEvent) -> String {
        switch reminder.reminderType {
        case .beforeEvent:
            let minutes = reminder.minutesBefore ?? 0
            return String(localized: "Starts in \(minutes) minutes")
        case .exactTime:
            let time = event.startsAt.formatted(date: .omitted, time: .shortened)
            return String(localized: "Scheduled at \(time)")
        }
    }

    private func notificationId(for dose: ScheduledDose) -> String {
        let comps = dose.fireDate
        let day = String(format: "%04d%02d%02d",
                         comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
        return "dose.\(dose.medicationId).\(dose.ruleId).\(dose.timeId).\(day)"
    }
}

// No-op implementation for SwiftUI Previews.
struct PreviewNotificationScheduler: NotificationScheduler {
    func requestPermission() async -> Bool { true }
    func schedule(doses: [ScheduledDose]) async {}
    func cancelAll(medicationId: Int64) async {}
    func cancelAll() {}
    func scheduleEventReminder(_ reminder: EventReminder, for event: CalendarEvent) async throws {}
    func cancelEventReminder(id: Int64) async {}
}
