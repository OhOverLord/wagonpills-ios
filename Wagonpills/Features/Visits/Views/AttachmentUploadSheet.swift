import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct AttachmentUploadSheet: View {
    let visitId: Int64
    let repository: any VisitRepository
    let onUploaded: ([VisitAttachment]) -> Void

    @State private var vm: AttachmentUploadViewModel
    @State private var showFilePicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var noteText = ""
    @Environment(\.dismiss) private var dismiss

    init(visitId: Int64, repository: any VisitRepository, onUploaded: @escaping ([VisitAttachment]) -> Void) {
        self.visitId = visitId
        self.repository = repository
        self.onUploaded = onUploaded
        _vm = State(wrappedValue: AttachmentUploadViewModel(visitId: visitId, repository: repository))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Note (optional)", text: $noteText)
                }
                Section {
                    uploadStatusView
                }
                Section {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 10,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Pick Photos", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isUploading)

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Pick Files", systemImage: "doc.badge.plus")
                    }
                    .disabled(isUploading)
                }
            }
            .navigationTitle("Add Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .png, .jpeg, .image, .data],
                allowsMultipleSelection: true,
                onCompletion: handleFilesPick
            )
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                handlePhotosPick(newItems)
            }
            .onChange(of: vm.uploadState) { _, newState in
                if case .done(let attachments) = newState {
                    onUploaded(attachments)
                    dismiss()
                }
            }
        }
    }

    private var isUploading: Bool {
        if case .uploading = vm.uploadState { return true }
        return false
    }

    @ViewBuilder
    private var uploadStatusView: some View {
        switch vm.uploadState {
        case .idle:
            Text("Select files or photos to upload")
                .foregroundStyle(.secondary)
        case .uploading(let current, let total):
            HStack {
                ProgressView()
                Text("Uploading \(current) of \(total)…")
                    .foregroundStyle(.secondary)
            }
        case .done:
            Label("Upload complete", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .partialFailure(let succeeded, let failedCount, let lastError):
            VStack(alignment: .leading, spacing: 4) {
                Label(
                    "\(failedCount) file(s) failed. \(succeeded.count) uploaded successfully.",
                    systemImage: "exclamationmark.circle.fill"
                )
                .foregroundStyle(.orange)
                if !lastError.isEmpty {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func handleFilesPick(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result, !urls.isEmpty else { return }
        var files: [AttachmentUploadViewModel.FileSelection] = []
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }
            files.append(.init(data: data, fileName: url.lastPathComponent, mimeType: url.mimeType))
        }
        guard !files.isEmpty else { return }
        let note = noteText.isEmpty ? nil : noteText
        Task {
            await vm.upload(files: files, note: note)
        }
    }

    private func handlePhotosPick(_ items: [PhotosPickerItem]) {
        let note = noteText.isEmpty ? nil : noteText
        Task {
            var files: [AttachmentUploadViewModel.FileSelection] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let rawIdentifier = (item.itemIdentifier ?? UUID().uuidString)
                    .replacingOccurrences(of: "/", with: "_")
                let fileName = rawIdentifier + ".jpeg"
                files.append(.init(data: data, fileName: fileName, mimeType: "image/jpeg"))
            }
            guard !files.isEmpty else { return }
            await vm.upload(files: files, note: note)
        }
        selectedPhotoItems = []
    }
}

private extension URL {
    var mimeType: String {
        guard let type = UTType(filenameExtension: pathExtension) else {
            return "application/octet-stream"
        }
        return type.preferredMIMEType ?? "application/octet-stream"
    }
}

#Preview {
    AttachmentUploadSheet(
        visitId: 1,
        repository: PreviewVisitRepository(),
        onUploaded: { _ in }
    )
}
