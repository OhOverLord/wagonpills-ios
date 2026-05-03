import SwiftUI

struct MainTabView: View {
    let authRepository: any AuthRepository
    let medicationRepository: any MedicationRepository
    let reminderRepository: any ReminderRepository
    let intakeLogRepository: any IntakeLogRepository

    @Environment(\.notificationRescheduler) private var notificationRescheduler

    var body: some View {
        TabView {
            TodayView(viewModel: TodayViewModel(
                medicationRepository: medicationRepository,
                reminderRepository: reminderRepository,
                intakeLogRepository: intakeLogRepository,
                notificationRescheduler: notificationRescheduler
            ))
            .tabItem { Label("Today", systemImage: "checkmark.circle") }

            MedicationListView(
                viewModel: MedicationListViewModel(repository: medicationRepository),
                reminderRepository: reminderRepository
            )
            .tabItem { Label("Medications", systemImage: "pills") }

            VisitListView()
                .tabItem { Label("Visits", systemImage: "stethoscope") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            SettingsView(authRepository: authRepository)
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
        .task { await rescheduleOnLaunch() }
    }

    private func rescheduleOnLaunch() async {
        guard let medications = try? await medicationRepository.fetchAll(activeOnly: true) else { return }
        await notificationRescheduler.rescheduleAll(medicationIds: medications.map { $0.id })
    }
}

#Preview {
    MainTabView(
        authRepository: PreviewAuthRepository(),
        medicationRepository: PreviewMedicationRepository(),
        reminderRepository: PreviewReminderRepository(),
        intakeLogRepository: PreviewIntakeLogRepository()
    )
    .environment(AuthState.preview(signedIn: "user@example.com"))
}
