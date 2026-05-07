import SwiftUI

struct CalendarEventDetailView: View {
    @State private var vm: CalendarEventDetailViewModel
    @State private var showingEdit = false
    @State private var showingAddReminder = false
    @State private var reminderToDelete: EventReminder?
    @State private var showDeleteReminderAlert = false

    init(viewModel: CalendarEventDetailViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch vm.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let event):
                eventContent(event)
            case .failed(let error):
                ContentUnavailableView(
                    "Could not load event",
                    systemImage: "wifi.slash",
                    description: Text(error.localizedDescription)
                )
            }
        }
        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .alert("Delete Reminder?", isPresented: $showDeleteReminderAlert, presenting: reminderToDelete) { reminder in
            Button("Delete", role: .destructive) {
                Task { await vm.deleteReminder(reminder) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This reminder will no longer fire.")
        }
    }

    @ViewBuilder
    private func eventContent(_ event: CalendarEvent) -> some View {
        List {
            overviewSection(event)
            remindersSection(event)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(
            isPresented: $showingEdit,
            onDismiss: { Task { await vm.load() } },
            content: {
                CalendarEventEditView(
                    viewModel: CalendarEventEditViewModel(mode: .edit(event), repository: vm.repository)
                )
            }
        )
        .sheet(
            isPresented: $showingAddReminder,
            onDismiss: { Task { await vm.load() } },
            content: {
                EventReminderEditView(
                    viewModel: EventReminderEditViewModel(
                        eventId: event.id,
                        repository: vm.repository,
                        scheduler: vm.scheduler
                    ),
                    event: event
                )
            }
        )
    }

    private func overviewSection(_ event: CalendarEvent) -> some View {
        Section("Overview") {
            HStack {
                Text("Type")
                Spacer()
                Label(event.type.displayName, systemImage: event.type.systemImage)
                    .foregroundStyle(event.type.color)
            }

            if event.isCancelled {
                Label("Cancelled", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }

            LabeledContent("Starts", value: event.startsAt.formatted(date: .abbreviated, time: .shortened))

            if let endsAt = event.endsAt {
                LabeledContent("Ends", value: endsAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let description = event.description, !description.isEmpty {
                Text(description)
                    .foregroundStyle(.secondary)
            }

            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
            }

            if let visitId = event.doctorVisitId {
                if let visitRepo = vm.visitRepository {
                    NavigationLink(destination: VisitDetailView(
                        viewModel: VisitDetailViewModel(visitId: visitId, repository: visitRepo)
                    )) {
                        Label("Open Doctor Visit", systemImage: "stethoscope")
                    }
                } else {
                    LabeledContent("Doctor Visit", value: "#\(visitId)")
                }
            }
        }
    }

    private func remindersSection(_ event: CalendarEvent) -> some View {
        Section {
            if event.reminders.isEmpty {
                Text("No reminders set")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(event.reminders) { reminder in
                    ReminderRowView(reminder: reminder)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                reminderToDelete = reminder
                                showDeleteReminderAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }

            Button {
                showingAddReminder = true
            } label: {
                Label("Add Reminder", systemImage: "bell.badge.plus")
            }
        } header: {
            Text("Reminders")
        }
    }
}

// MARK: - Reminder row

private struct ReminderRowView: View {
    let reminder: EventReminder

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminderTitle)
                    .font(.subheadline)
                HStack {
                    Text(channelLabel)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(reminder.channel == .push ? Color.blue : Color.gray, in: Capsule())

                    if !reminder.isActive {
                        Text("Inactive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "bell")
                .foregroundStyle(.secondary)
        }
    }

    private var reminderTitle: String {
        switch reminder.reminderType {
        case .beforeEvent:
            let minutes = reminder.minutesBefore ?? 0
            return String(localized: "\(minutes) min before")
        case .exactTime:
            guard let time = reminder.reminderAt else { return String(localized: "Exact time") }
            return time.formatted(date: .abbreviated, time: .shortened)
        }
    }

    private var channelLabel: String {
        reminder.channel == .push ? "Push" : "Email"
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        CalendarEventDetailView(viewModel: CalendarEventDetailViewModel(
            eventId: 1,
            repository: PreviewCalendarRepository(),
            scheduler: PreviewNotificationScheduler()
        ))
    }
}
