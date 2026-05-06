import SwiftUI

struct PrescriptionDetailView: View {
    @State private var vm: PrescriptionDetailViewModel
    @State private var editingPrescription: Prescription?
    @State private var editingItem: PrescriptionItem?
    @State private var showingAddItem = false
    @State private var itemToDelete: PrescriptionItem?
    @State private var showDeleteItemAlert = false

    init(viewModel: PrescriptionDetailViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch vm.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let prescription):
                prescriptionContent(prescription)
            case .failed(let error):
                errorView(error)
            }
        }
        .navigationTitle("Prescription")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(item: $editingPrescription, onDismiss: {
            Task { await vm.load() }
        }, content: { prescription in
            PrescriptionEditView(
                mode: .edit(prescription),
                repository: vm.repository,
                availableVisits: vm.availableVisits
            )
        })
        .sheet(isPresented: $showingAddItem, onDismiss: {
            Task { await vm.load() }
        }, content: {
            if case .loaded(let prescription) = vm.state {
                PrescriptionItemEditView(
                    mode: .create(prescriptionId: prescription.id),
                    repository: vm.repository
                )
            }
        })
        .sheet(item: $editingItem, onDismiss: {
            Task { await vm.load() }
        }, content: { item in
            PrescriptionItemEditView(mode: .edit(item), repository: vm.repository)
        })
        .alert("Delete Item?", isPresented: $showDeleteItemAlert, presenting: itemToDelete) { item in
            Button("Delete", role: .destructive) {
                Task { await vm.deleteItem(item) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("Remove \"\(item.medicationName)\" from this prescription?")
        }
        .task { await vm.load() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if case .loaded(let prescription) = vm.state {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editingPrescription = prescription }
            }
        }
    }

    private func prescriptionContent(_ prescription: Prescription) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection(prescription)
                itemsSection(prescription)
            }
            .padding()
        }
    }

    private func headerSection(_ prescription: Prescription) -> some View {
        PrescriptionSectionCard(title: "Details") {
            LabeledContent("Issued", value: prescription.formattedIssuedAt)
            if prescription.doctorVisitId != nil {
                LabeledContent("Visit", value: vm.linkedVisit.map(visitLabel) ?? "Loading…")
            }
            if let note = prescription.note {
                LabeledContent("Note", value: note)
            }
            LabeledContent("Added", value: prescription.createdAt.formatted(.relative(presentation: .named)))
        }
    }

    private func visitLabel(_ visit: Visit) -> String {
        let date = visit.visitAt.formatted(date: .abbreviated, time: .omitted)
        if let doctor = visit.doctorName {
            return "\(doctor) — \(date)"
        }
        return date
    }

    private func itemsSection(_ prescription: Prescription) -> some View {
        PrescriptionSectionCard(title: "Items") {
            if prescription.items.isEmpty {
                Text("No items")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(prescription.items) { item in
                    itemRow(item)
                }
            }
            Button {
                showingAddItem = true
            } label: {
                Label("Add Item", systemImage: "plus.circle")
            }
        }
    }

    private func itemRow(_ item: PrescriptionItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.medicationName)
                .font(.subheadline)
                .fontWeight(.medium)
            if let dosage = item.dosageText {
                Text(dosage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let days = item.durationDays {
                Text("\(days) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { editingItem = item }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                itemToDelete = item
                showDeleteItemAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func errorView(_ error: APIError) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Could not load prescription",
                systemImage: "wifi.slash",
                description: Text(error.localizedDescription)
            )
            Button("Retry") { Task { await vm.load() } }
                .buttonStyle(.bordered)
        }
    }
}

// MARK: - Section card

private struct PrescriptionSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Previews

#Preview("Loaded") {
    let prescriptions = PreviewPrescriptionRepository.makeSamplePrescriptions()
    NavigationStack {
        PrescriptionDetailView(viewModel: PrescriptionDetailViewModel(
            prescriptionId: 1,
            repository: PreviewPrescriptionRepository(prescriptions: prescriptions),
            visitRepository: PreviewVisitRepository()
        ))
    }
}

#Preview("No items") {
    let prescriptions = PreviewPrescriptionRepository.makeSamplePrescriptions()
    NavigationStack {
        PrescriptionDetailView(viewModel: PrescriptionDetailViewModel(
            prescriptionId: 2,
            repository: PreviewPrescriptionRepository(prescriptions: prescriptions),
            visitRepository: PreviewVisitRepository()
        ))
    }
}
