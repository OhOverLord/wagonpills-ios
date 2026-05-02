import SwiftUI

struct ReminderRuleEditView: View {
    @State private var vm: ReminderRuleEditViewModel
    @State private var showTimePicker = false
    @State private var pickerTime = Date()
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ReminderRuleEditViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                repeatSection
                if vm.repeatType == .weekly { weekdaySection }
                if vm.repeatType == .interval { intervalSection }
                timesSection

                if case .edit = vm.mode {
                    deleteSection
                }
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
                isPresented: Binding(get: { vm.deleteError != nil }, set: { if !$0 { vm.deleteError = nil } }),
                presenting: vm.deleteError
            ) { _ in
                Button("OK", role: .cancel) { vm.deleteError = nil }
            } message: { error in
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Sections

    private var repeatSection: some View {
        Section("Repeat") {
            Picker("Type", selection: $vm.repeatType) {
                ForEach(RepeatType.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.menu)

            if let error = vm.validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var weekdaySection: some View {
        Section("Days of week") {
            ForEach(Weekday.allCases, id: \.self) { day in
                Toggle(day.displayName, isOn: Binding(
                    get: { vm.selectedDays.contains(day) },
                    set: { isOn in
                        if isOn { vm.selectedDays.insert(day) } else { vm.selectedDays.remove(day) }
                    }
                ))
            }
        }
    }

    private var intervalSection: some View {
        Section("Interval") {
            HStack {
                Text("Every")
                TextField("1", text: $vm.intervalDaysText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text("day(s)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timesSection: some View {
        Section {
            ForEach(vm.times) { draft in
                Text(draft.displayString)
            }
            .onDelete { offsets in vm.removeTime(at: offsets) }

            Button {
                pickerTime = Calendar.current.date(
                    bySettingHour: 8, minute: 0, second: 0, of: Date()
                ) ?? Date()
                showTimePicker = true
            } label: {
                Label("Add Time", systemImage: "plus.circle")
            }
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
            times: [ReminderTime(id: 1, hour: 8, minute: 0)]
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
            times: [ReminderTime(id: 2, hour: 9, minute: 30)]
        )),
        medicationId: 1,
        repository: PreviewReminderRepository()
    ))
}
