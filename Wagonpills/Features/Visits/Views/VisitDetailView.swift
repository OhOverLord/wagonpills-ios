import QuickLook
import SwiftUI

struct VisitDetailView: View {
    @State private var vm: VisitDetailViewModel
    @State private var editingVisit: Visit?
    @State private var showingAddAttachment = false
    @State private var attachmentToDelete: VisitAttachment?
    @State private var showDeleteAttachmentAlert = false

    init(viewModel: VisitDetailViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        @Bindable var bindableVM = vm
        Group {
            switch vm.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let visit):
                visitContent(visit)
            case .failed(let error):
                errorView(error)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(item: $editingVisit, onDismiss: {
            Task { await vm.load() }
        }, content: { visit in
            VisitEditView(mode: .edit(visit), repository: vm.repository)
        })
        .sheet(isPresented: $showingAddAttachment, onDismiss: {
            Task { await vm.load() }
        }, content: {
            AttachmentUploadSheet(
                visitId: vm.visitId,
                repository: vm.repository,
                onUploaded: { _ in showingAddAttachment = false }
            )
        })
        .alert("Download Failed", isPresented: Binding(
            get: { vm.downloadError != nil },
            set: { if !$0 { vm.clearDownloadError() } }
        )) {
            Button("OK", role: .cancel) { vm.clearDownloadError() }
        } message: {
            Text(vm.downloadError?.localizedDescription ?? "")
        }
        .alert("Delete Attachment?", isPresented: $showDeleteAttachmentAlert, presenting: attachmentToDelete) { attachment in
            Button("Delete", role: .destructive) {
                Task { await vm.deleteAttachment(attachment) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { attachment in
            Text("\"\(attachment.fileName)\" will be permanently removed.")
        }
        .quickLookPreview($bindableVM.previewURL)
        .task { await vm.load() }
    }

    private var navigationTitle: String {
        if case .loaded(let visit) = vm.state {
            return visit.doctorName ?? String(localized: "Visit Details")
        }
        return ""
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if case .loaded(let visit) = vm.state {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editingVisit = visit }
            }
        }
    }

    private func visitContent(_ visit: Visit) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                overviewSection(visit)
                if visit.diagnosis != nil || visit.recommendations != nil {
                    clinicalSection(visit)
                }
                attachmentsSection(visit)
                metadataSection(visit)
            }
            .padding()
        }
    }

    private func overviewSection(_ visit: Visit) -> some View {
        VisitSectionCard(title: "Overview") {
            if let doctor = visit.doctorName {
                LabeledContent("Doctor", value: doctor)
            }
            if let specialty = visit.specialty {
                LabeledContent("Specialty", value: specialty)
            }
            LabeledContent("Date", value: visit.visitAt.formatted(date: .abbreviated, time: .shortened))
            if let location = visit.location {
                LabeledContent("Location", value: location)
            }
        }
    }

    private func clinicalSection(_ visit: Visit) -> some View {
        VisitSectionCard(title: "Clinical") {
            if let diagnosis = visit.diagnosis {
                LabeledContent("Diagnosis", value: diagnosis)
            }
            if let recommendations = visit.recommendations {
                LabeledContent("Recommendations", value: recommendations)
            }
        }
    }

    private func attachmentsSection(_ visit: Visit) -> some View {
        VisitSectionCard(title: "Attachments") {
            if visit.attachments.isEmpty {
                Text("No attachments")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visit.attachments) { attachment in
                    attachmentRow(attachment)
                }
            }
            Button {
                showingAddAttachment = true
            } label: {
                Label("Add Attachment", systemImage: "paperclip")
            }
        }
    }

    private func attachmentRow(_ attachment: VisitAttachment) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.subheadline)
                if let note = attachment.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(attachment.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if vm.isDownloadingAttachmentId == attachment.id {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button {
                    Task { await vm.downloadAndPreview(attachment) }
                } label: {
                    Image(systemName: "eye")
                }
                .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                attachmentToDelete = attachment
                showDeleteAttachmentAlert = true
            } label: {
                Label("Delete attachment", systemImage: "trash")
            }
        }
    }

    private func metadataSection(_ visit: Visit) -> some View {
        VisitSectionCard(title: "Info") {
            LabeledContent("Added", value: visit.createdAt.formatted(.relative(presentation: .named)))
        }
    }

    private func errorView(_ error: APIError) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Could not load visit",
                systemImage: "wifi.slash",
                description: Text(error.localizedDescription)
            )
            Button("Retry") { Task { await vm.load() } }
                .buttonStyle(.bordered)
        }
    }
}

// MARK: - Section card

private struct VisitSectionCard<Content: View>: View {
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

// MARK: - VisitAttachment display helpers

private extension VisitAttachment {
    var formattedSize: String {
        let bytes = Double(fileSizeBytes)
        if bytes < 1_024 { return "\(fileSizeBytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", bytes / 1_024) }
        return String(format: "%.1f MB", bytes / 1_048_576)
    }
}

// MARK: - Previews

#Preview("Loaded") {
    let visits = PreviewVisitRepository.makeSampleVisits()
    NavigationStack {
        VisitDetailView(viewModel: VisitDetailViewModel(
            visitId: 1,
            repository: PreviewVisitRepository(visits: visits)
        ))
    }
}

#Preview("Empty attachments") {
    let visits = PreviewVisitRepository.makeSampleVisits()
    NavigationStack {
        VisitDetailView(viewModel: VisitDetailViewModel(
            visitId: 2,
            repository: PreviewVisitRepository(visits: visits)
        ))
    }
}
