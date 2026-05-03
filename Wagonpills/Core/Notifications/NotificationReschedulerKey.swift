import SwiftUI

private struct NotificationReschedulerKey: EnvironmentKey {
    static let defaultValue: any NotificationRescheduler = NoOpNotificationRescheduler()
}

extension EnvironmentValues {
    var notificationRescheduler: any NotificationRescheduler {
        get { self[NotificationReschedulerKey.self] }
        set { self[NotificationReschedulerKey.self] = newValue }
    }
}
