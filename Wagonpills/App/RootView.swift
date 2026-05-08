import SwiftUI

struct RootView: View {
    @Environment(AuthState.self) private var authState
    let authRepository: any AuthRepository
    let medicationRepository: any MedicationRepository
    let reminderRepository: any ReminderRepository
    let intakeLogRepository: any IntakeLogRepository
    let catalogRepository: any CatalogRepository
    let visitRepository: any VisitRepository
    let prescriptionRepository: any PrescriptionRepository
    let calendarRepository: any CalendarRepository
    let regionRepository: any RegionRepository

    var body: some View {
        switch authState.status {
        case .unknown:
            SplashView()
                .task { authState.bootstrap() }
        case .signedOut:
            AuthFlowView(repository: authRepository, authState: authState)
        case .signedIn:
            MainTabView(
                authRepository: authRepository,
                medicationRepository: medicationRepository,
                reminderRepository: reminderRepository,
                intakeLogRepository: intakeLogRepository,
                catalogRepository: catalogRepository,
                visitRepository: visitRepository,
                prescriptionRepository: prescriptionRepository,
                calendarRepository: calendarRepository,
                regionRepository: regionRepository
            )
        }
    }
}

#Preview("Signed out") {
    RootView(
        authRepository: PreviewAuthRepository(),
        medicationRepository: PreviewMedicationRepository(),
        reminderRepository: PreviewReminderRepository(),
        intakeLogRepository: PreviewIntakeLogRepository(),
        catalogRepository: PreviewCatalogRepository(),
        visitRepository: PreviewVisitRepository(),
        prescriptionRepository: PreviewPrescriptionRepository(),
        calendarRepository: PreviewCalendarRepository(),
        regionRepository: PreviewRegionRepository()
    )
    .environment(AuthState.previewSignedOut())
}

#Preview("Signed in") {
    RootView(
        authRepository: PreviewAuthRepository(),
        medicationRepository: PreviewMedicationRepository(),
        reminderRepository: PreviewReminderRepository(),
        intakeLogRepository: PreviewIntakeLogRepository(),
        catalogRepository: PreviewCatalogRepository(),
        visitRepository: PreviewVisitRepository(),
        prescriptionRepository: PreviewPrescriptionRepository(),
        calendarRepository: PreviewCalendarRepository(),
        regionRepository: PreviewRegionRepository()
    )
    .environment(AuthState.preview(signedIn: "user@example.com"))
}
