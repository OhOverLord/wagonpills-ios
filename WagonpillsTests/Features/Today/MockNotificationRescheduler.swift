import Foundation
@testable import Wagonpills

final class MockNotificationRescheduler: NotificationRescheduler, @unchecked Sendable {
    private(set) var rescheduleCallCount = 0
    private(set) var lastRescheduledMedicationId: Int64?

    func rescheduleNotifications(for medicationId: Int64) async {
        rescheduleCallCount += 1
        lastRescheduledMedicationId = medicationId
    }

    func rescheduleAll(medicationIds: [Int64]) async {}
}
