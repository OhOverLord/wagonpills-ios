import SwiftUI

struct CalendarEventEditView: View {
    @State private var vm: CalendarEventEditViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: CalendarEventEditViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                detailsSection
                timingSection
            }
            .navigationTitle(vm.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!vm.isTitleValid || vm.saveState == .saving)
                }
            }
            .disabled(vm.saveState == .saving)
            .onChange(of: vm.saveState) { _, state in
                if state == .saved { dismiss() }
            }
        }
    }

    private var typeSection: some View {
        Section("Event Type") {
            if case .edit = vm.mode {
                HStack {
                    Text("Type")
                    Spacer()
                    Label(vm.type.displayName, systemImage: vm.type.systemImage)
                        .foregroundStyle(vm.type.color)
                }
            } else {
                Picker("Type", selection: $vm.type) {
                    ForEach(CalendarEventType.allCases, id: \.self) { eventType in
                        Label(eventType.displayName, systemImage: eventType.systemImage)
                            .tag(eventType)
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $vm.title)

            if case .create = vm.mode, vm.type == .doctorVisit {
                TextField("Doctor name (optional)", text: $vm.doctorName)
            }

            TextField("Description (optional)", text: $vm.description, axis: .vertical)
                .lineLimit(3...6)
            TextField("Location (optional)", text: $vm.location)

            if case .failed(let error) = vm.saveState {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }

    private var timingSection: some View {
        Section("Timing") {
            DatePicker("Starts", selection: $vm.startsAt, displayedComponents: [.date, .hourAndMinute])

            Toggle("End time", isOn: $vm.hasEndDate)

            if vm.hasEndDate {
                DatePicker("Ends", selection: $vm.endsAt, in: vm.startsAt..., displayedComponents: [.date, .hourAndMinute])
            }
        }
    }

    private func save() async {
        await vm.save()
    }
}

// MARK: - Previews

#Preview("Create") {
    CalendarEventEditView(
        viewModel: CalendarEventEditViewModel(mode: .create, repository: PreviewCalendarRepository())
    )
}

#Preview("Edit") {
    CalendarEventEditView(
        viewModel: CalendarEventEditViewModel(
            mode: .edit(PreviewCalendarRepository.sampleEvents[0]),
            repository: PreviewCalendarRepository()
        )
    )
}
