import Observation

@MainActor
@Observable
final class AppDependencies {
    let authState: AuthState
    let authRepository: any AuthRepository
    let medicationRepository: any MedicationRepository
    let reminderRepository: any ReminderRepository
    let intakeLogRepository: any IntakeLogRepository
    let catalogRepository: any CatalogRepository
    let visitRepository: any VisitRepository
    let notificationRescheduler: any NotificationRescheduler

    init() {
        let tokenStore = KeychainStore()
        let state = AuthState(tokenStore: tokenStore)
        let apiClient = APIClient(tokenStore: tokenStore, authState: state)
        let cache = URLCacheStore()
        let medRepo = LiveMedicationRepository(apiClient: apiClient, cache: cache)
        let reminderRepo = LiveReminderRepository(apiClient: apiClient, cache: cache)
        self.authState = state
        self.authRepository = LiveAuthRepository(apiClient: apiClient)
        self.medicationRepository = medRepo
        self.reminderRepository = reminderRepo
        self.intakeLogRepository = LiveIntakeLogRepository(apiClient: apiClient, cache: cache)
        self.catalogRepository = LiveCatalogRepository(apiClient: apiClient, cache: cache)
        self.visitRepository = LiveVisitRepository(apiClient: apiClient, cache: cache)
        self.notificationRescheduler = LiveNotificationRescheduler(
            reminderRepository: reminderRepo,
            medicationRepository: medRepo,
            scheduler: LiveNotificationScheduler()
        )
    }
}
