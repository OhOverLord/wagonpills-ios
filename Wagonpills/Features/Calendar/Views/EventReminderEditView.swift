import SwiftUI

struct EventReminderEditView: View {
    @State private var vm: EventReminderEditViewModel
    @Environment(\.dismiss) private var dismiss

    let event: CalendarEvent

    init(viewModel: EventReminderEditViewModel, event: CalendarEvent) {
        _vm = State(wrappedValue: viewModel)
        self.event = event
    }

    var body: some View {
        NavigationStack {
            Form {
                typePicker
                triggerSection
                channelNote
                statusSection
            }
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await vm.save(for: event) }
                    }
                    .disabled(vm.saveState == .saving)
                }
            }
            .disabled(vm.saveState == .saving)
            .onChange(of: vm.saveState) { _, state in
                if state == .saved { dismiss() }
            }
        }
    }

    private var typePicker: some View {
        Section("Reminder Type") {
            Picker("When", selection: $vm.reminderType) {
                Text("Before event").tag(EventReminderType.beforeEvent)
                Text("Exact time").tag(EventReminderType.exactTime)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var triggerSection: some View {
        if vm.reminderType == .beforeEvent {
            Section("Minutes Before") {
                Stepper("\(vm.minutesBefore) minutes", value: $vm.minutesBefore, in: 5...1440, step: 5)
            }
        } else {
            Section("Reminder Time") {
                DatePicker(
                    "At",
                    selection: $vm.reminderAt,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
        }
    }

    private var channelNote: some View {
        Section {
            Label("Push notification (local)", systemImage: "bell")
                .foregroundStyle(.secondary)
        } footer: {
            Text("Reminders fire on-device and work offline.")
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if case .failed(let error) = vm.saveState {
            Section {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        } else if vm.saveState == .permissionDenied {
            Section {
                Label(
                    "Notification permission is denied. Enable it in Settings to receive reminders.",
                    systemImage: "bell.slash"
                )
                .foregroundStyle(.orange)
                .font(.footnote)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    EventReminderEditView(
        viewModel: EventReminderEditViewModel(
            eventId: 1,
            repository: PreviewCalendarRepository(),
            scheduler: PreviewNotificationScheduler()
        ),
        event: PreviewCalendarRepository.sampleEvents[0]
    )
}
