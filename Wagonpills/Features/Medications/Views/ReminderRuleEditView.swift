import SwiftUI
import UserNotifications

struct ReminderRuleEditView: View {
    @State private var vm: ReminderRuleEditViewModel
    @State private var showTimePicker = false
    @State private var pickerTime = Date()
    @State private var showDeleteConfirmation = false
    @State private var showPermissionSheet = false
    @State private var openTimePickerAfterPermission = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ReminderRuleEditViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                reminderSection
                if vm.repeatType == .interval { intervalSection }
                timesSection
                if case .edit = vm.mode { deleteSection }
            }
            .navigationTitle(vm.mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.saveState == .saving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await vm.save() } }
                    }
                }
            }
            .onChange(of: vm.saveState) { _, newValue in
                if case .saved = newValue { dismiss() }
            }
            .sheet(isPresented: $showTimePicker) {
                timePickerSheet
            }
            .sheet(isPresented: $showPermissionSheet) {
                NotificationPermissionView()
                    .onDisappear {
                        if openTimePickerAfterPermission {
                            openTimePickerAfterPermission = false
                            showTimePicker = true
                        }
                    }
            }
            .confirmationDialog(
                "Delete this reminder rule?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { Task { await vm.delete() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the rule and all its times.")
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { vm.deleteError != nil },
                    set: { if !$0 { vm.deleteError = nil } }
                ),
                presenting: vm.deleteError
            ) { _ in
                Button("OK", role: .cancel) { vm.deleteError = nil }
            } message: { error in
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Sections

    private var reminderSection: some View {
        Section("Reminder") {
            Toggle(isOn: $vm.active) {
                Text("Reminder")
                    .fontWeight(.semibold)
            }

            Picker(selection: $vm.repeatType) {
                ForEach(RepeatType.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            } label: {
                Text("Repeat")
                    .fontWeight(.semibold)
            }
            .pickerStyle(.navigationLink)

            if vm.repeatType == .weekly {
                weekdayPills
            }

            if let error = vm.validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var weekdayPills: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let selected = vm.selectedDays.contains(day)
                Button {
                    if selected {
                        vm.selectedDays.remove(day)
                    } else {
                        vm.selectedDays.insert(day)
                    }
                } label: {
                    Text(day.shortName)
                        .font(.subheadline.bold())
                        .frame(width: 36, height: 36)
                        .background(selected ? Color.primary : Color.clear)
                        .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: selected ? 0 : 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }

    private var intervalSection: some View {
        Section("Interval (Days)") {
            HStack {
                Text(vm.intervalDaysText)
                    .font(.body)
                Spacer()
                Stepper(
                    "",
                    value: Binding(
                        get: { Int(vm.intervalDaysText) ?? 1 },
                        set: { vm.intervalDaysText = String($0) }
                    ),
                    in: 1...365
                )
                .labelsHidden()
            }
        }
    }

    private var timesSection: some View {
        Section {
            ForEach(vm.times) { draft in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                            .frame(width: 38, height: 38)
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    Text(draft.displayString)
                        .font(.body.bold())

                    Spacer()

                    Button {
                        if let idx = vm.times.firstIndex(of: draft) {
                            vm.removeTime(at: IndexSet(integer: idx))
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                                .frame(width: 28, height: 28)
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }

            Button {
                Task { await handleAddTimeTapped() }
            } label: {
                Text("+ Add Time")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        } header: {
            Text("Times")
        } footer: {
            if vm.times.isEmpty {
                Text("At least one time is required.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Rule", role: .destructive) {
                showDeleteConfirmation = true
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Helpers

    private func handleAddTimeTapped() async {
        pickerTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()

        if case .create = vm.mode, vm.times.isEmpty {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                openTimePickerAfterPermission = true
                showPermissionSheet = true
                return
            }
        }
        showTimePicker = true
    }

    // MARK: - Time picker sheet

    private var timePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Time",
                    selection: $pickerTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            .navigationTitle("Select Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTimePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let cal = Calendar.current
                        var comps = DateComponents()
                        comps.hour = cal.component(.hour, from: pickerTime)
                        comps.minute = cal.component(.minute, from: pickerTime)
                        vm.addTime(comps)
                        showTimePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Previews

#Preview("Create") {
    ReminderRuleEditView(viewModel: ReminderRuleEditViewModel(
        mode: .create,
        medicationId: 1,
        repository: PreviewReminderRepository()
    ))
}

#Preview("Edit DAILY") {
    ReminderRuleEditView(viewModel: ReminderRuleEditViewModel(
        mode: .edit(ReminderRule(
            id: 1, repeatType: .daily, intervalDays: nil, daysOfWeek: [],
            active: true,
            times: [
                ReminderTime(id: 1, hour: 8, minute: 0),
                ReminderTime(id: 2, hour: 20, minute: 0)
            ]
        )),
        medicationId: 1,
        repository: PreviewReminderRepository()
    ))
}

#Preview("Edit WEEKLY") {
    ReminderRuleEditView(viewModel: ReminderRuleEditViewModel(
        mode: .edit(ReminderRule(
            id: 2, repeatType: .weekly, intervalDays: nil,
            daysOfWeek: [.monday, .wednesday, .friday],
            active: true,
            times: [
                ReminderTime(id: 3, hour: 8, minute: 0),
                ReminderTime(id: 4, hour: 20, minute: 0)
            ]
        )),
        medicationId: 1,
        repository: PreviewReminderRepository()
    ))
}

#Preview("Edit INTERVAL") {
    ReminderRuleEditView(viewModel: ReminderRuleEditViewModel(
        mode: .edit(ReminderRule(
            id: 3, repeatType: .interval, intervalDays: 3, daysOfWeek: [],
            active: true,
            times: [
                ReminderTime(id: 5, hour: 8, minute: 0),
                ReminderTime(id: 6, hour: 20, minute: 0)
            ]
        )),
        medicationId: 1,
        repository: PreviewReminderRepository()
    ))
}
