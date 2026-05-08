import SwiftUI

struct SettingsView: View {
    @Environment(AuthState.self) private var authState
    let authRepository: any AuthRepository
    let prescriptionRepository: any PrescriptionRepository
    let visitRepository: any VisitRepository
    @StateObject private var vm: SettingsViewModel

    init(
        authRepository: any AuthRepository,
        prescriptionRepository: any PrescriptionRepository,
        visitRepository: any VisitRepository,
        regionRepository: any RegionRepository
    ) {
        self.authRepository = authRepository
        self.prescriptionRepository = prescriptionRepository
        self.visitRepository = visitRepository
        self._vm = StateObject(wrappedValue: SettingsViewModel(regionRepository: regionRepository))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Records") {
                    NavigationLink("Prescriptions") {
                        PrescriptionListView(viewModel: PrescriptionListViewModel(
                            repository: prescriptionRepository,
                            visitRepository: visitRepository
                        ))
                    }
                }

                Section("Preferences") {
                    regionRow
                }

                Section("Account") {
                    if case .signedIn(let email) = authState.status {
                        LabeledContent("Signed in as", value: email)
                    }
                    Button("Sign Out", role: .destructive) {
                        Task { await signOut() }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("More")
            .task { await vm.loadRegions() }
        }
    }

    @ViewBuilder
    private var regionRow: some View {
        switch vm.regionState {
        case .idle, .loading:
            HStack {
                Text("Region")
                Spacer()
                ProgressView()
            }
        case .loaded(let regions):
            Picker("Region", selection: $vm.selectedRegionCode) {
                ForEach(regions) { region in
                    Text(region.name).tag(region.code)
                }
            }
        case .failed:
            VStack(alignment: .leading, spacing: 2) {
                LabeledContent("Region", value: vm.selectedRegionCode)
                Text("Could not load regions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func signOut() async {
        // Best-effort: revoke the refresh token server-side before clearing
        // local state. Sign-out proceeds regardless of network outcome because
        // access tokens expire on their own and a stranded refresh token is
        // low risk compared to blocking the user in the app.
        if let tokens = authState.currentTokens() {
            try? await authRepository.logout(refreshToken: tokens.refreshToken)
        }
        authState.signOut()
    }
}

#Preview("Signed in") {
    SettingsView(
        authRepository: PreviewAuthRepository(),
        prescriptionRepository: PreviewPrescriptionRepository(),
        visitRepository: PreviewVisitRepository(),
        regionRepository: PreviewRegionRepository()
    )
    .environment(AuthState.preview(signedIn: "user@example.com"))
}

#Preview("Signed out") {
    SettingsView(
        authRepository: PreviewAuthRepository(),
        prescriptionRepository: PreviewPrescriptionRepository(),
        visitRepository: PreviewVisitRepository(),
        regionRepository: PreviewRegionRepository()
    )
    .environment(AuthState.previewSignedOut())
}
