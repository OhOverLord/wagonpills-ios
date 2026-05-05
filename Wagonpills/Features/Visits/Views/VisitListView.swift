import SwiftUI

struct VisitListView: View {
    @State private var vm: VisitListViewModel
    @State private var showingCreateVisit = false
    @State private var visitToDelete: Visit?
    @State private var showDeleteAlert = false

    init(viewModel: VisitListViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Visits")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCreateVisit = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingCreateVisit, onDismiss: {
                    Task { await vm.refresh() }
                }, content: {
                    VisitEditView(mode: .create, repository: vm.repository)
                })
                .alert("Delete Visit?", isPresented: $showDeleteAlert, presenting: visitToDelete) { visit in
                    Button("Delete", role: .destructive) {
                        Task { await vm.delete(visit) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { visit in
                    Text("Delete the record for \(visit.doctorName ?? "this visit")?")
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
                "No Visits",
                systemImage: "stethoscope",
                description: Text("Your doctor visit records will appear here.")
            )
        case .loaded(let visits):
            List {
                ForEach(visits) { visit in
                    NavigationLink(destination: visitDetail(for: visit)) {
                        VisitRowView(visit: visit)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            visitToDelete = visit
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
                    "Could not load visits",
                    systemImage: "wifi.slash",
                    description: Text(error.localizedDescription)
                )
                Button("Retry") { Task { await vm.refresh() } }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func visitDetail(for visit: Visit) -> some View {
        VisitDetailView(viewModel: VisitDetailViewModel(
            visitId: visit.id,
            repository: vm.repository
        ))
    }
}

// MARK: - Row

private struct VisitRowView: View {
    let visit: Visit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(visit.doctorName ?? String(localized: "Unknown doctor"))
                .font(.headline)
            if let specialty = visit.specialty {
                Text(specialty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(visit.visitAt, format: .dateTime.day().month(.abbreviated).year())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Loaded") {
    VisitListView(viewModel: VisitListViewModel(
        repository: PreviewVisitRepository()
    ))
}

#Preview("Empty") {
    VisitListView(viewModel: VisitListViewModel(
        repository: PreviewVisitRepository(visits: [])
    ))
}

#Preview("Error") {
    VisitListView(viewModel: VisitListViewModel(
        repository: PreviewVisitRepository(visits: [], error: .network)
    ))
}
