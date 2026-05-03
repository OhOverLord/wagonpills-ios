import Foundation
import UserNotifications

protocol NotificationScheduler: Sendable {
    func requestPermission() async -> Bool
    func schedule(doses: [ScheduledDose]) async
    func cancelAll(medicationId: Int64) async
    func cancelAll()
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

    // MARK: - Helpers

    private func notificationId(for dose: ScheduledDose) -> String {
        let comps = dose.fireDate
        let day = String(format: "%04d%02d%02d",
                         comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
        return "dose.\(dose.medicationId).\(dose.ruleId).\(dose.timeId).\(day)"
    }
}
