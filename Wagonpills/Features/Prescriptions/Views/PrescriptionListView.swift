import SwiftUI

struct PrescriptionListView: View {
    @State private var vm: PrescriptionListViewModel
    @State private var showingCreate = false
    @State private var prescriptionToDelete: Prescription?
    @State private var showDeleteAlert = false

    init(viewModel: PrescriptionListViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Prescriptions")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCreate = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingCreate, onDismiss: {
                    Task { await vm.refresh() }
                }, content: {
                    PrescriptionEditView(
                        mode: .create,
                        repository: vm.repository,
                        availableVisits: vm.availableVisits
                    )
                })
                .alert("Delete Prescription?", isPresented: $showDeleteAlert, presenting: prescriptionToDelete) { prescription in
                    Button("Delete", role: .destructive) {
                        Task { await vm.delete(prescription) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { prescription in
                    Text("Delete the prescription issued \(prescription.formattedIssuedAt) and all its items?")
                }
                .task { await vm.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView(
                "No Prescriptions",
                systemImage: "doc.text",
                description: Text("Your prescription records will appear here.")
            )
        case .loaded(let prescriptions):
            List {
                ForEach(prescriptions) { prescription in
                    NavigationLink(destination: prescriptionDetail(for: prescription)) {
                        PrescriptionRowView(prescription: prescription)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            prescriptionToDelete = prescription
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        case .failed(let error):
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "Could not load prescriptions",
                    systemImage: "wifi.slash",
                    description: Text(error.localizedDescription)
                )
                Button("Retry") { Task { await vm.refresh() } }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func prescriptionDetail(for prescription: Prescription) -> some View {
        PrescriptionDetailView(viewModel: PrescriptionDetailViewModel(
            prescriptionId: prescription.id,
            repository: vm.repository,
            visitRepository: vm.visitRepository
        ))
    }
}

// MARK: - Row

private struct PrescriptionRowView: View {
    let prescription: Prescription

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.plaintext")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(prescription.medicationsSummary)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(prescription.formattedIssuedAt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let note = prescription.note {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Prescription display helpers

extension Prescription {
    var formattedIssuedAt: String {
        guard let date = issuedAt else {
            return String(localized: "No date")
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var medicationsSummary: String {
        guard !items.isEmpty else {
            return String(localized: "No medications")
        }
        let names = items.prefix(2).map { $0.medicationName }
        let joined = names.joined(separator: ", ")
        return items.count > 2 ? "\(joined)…" : joined
    }
}

// MARK: - Previews

#Preview("Loaded") {
    PrescriptionListView(viewModel: PrescriptionListViewModel(
        repository: PreviewPrescriptionRepository(),
        visitRepository: PreviewVisitRepository()
    ))
}

#Preview("Empty") {
    PrescriptionListView(viewModel: PrescriptionListViewModel(
        repository: PreviewPrescriptionRepository(prescriptions: []),
        visitRepository: PreviewVisitRepository()
    ))
}

#Preview("Error") {
    PrescriptionListView(viewModel: PrescriptionListViewModel(
        repository: PreviewPrescriptionRepository(prescriptions: [], error: .network),
        visitRepository: PreviewVisitRepository()
    ))
}
