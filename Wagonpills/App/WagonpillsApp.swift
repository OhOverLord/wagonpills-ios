import SwiftUI

@main
struct WagonpillsApp: App {
    @State private var deps = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(
                authRepository: deps.authRepository,
                medicationRepository: deps.medicationRepository,
                reminderRepository: deps.reminderRepository,
                intakeLogRepository: deps.intakeLogRepository,
                catalogRepository: deps.catalogRepository,
                visitRepository: deps.visitRepository,
                prescriptionRepository: deps.prescriptionRepository,
                calendarRepository: deps.calendarRepository
            )
            .environment(deps.authState)
            .environment(\.notificationRescheduler, deps.notificationRescheduler)
        }
    }
}
