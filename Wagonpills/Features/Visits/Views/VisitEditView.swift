import SwiftUI

struct VisitEditView: View {
    @State private var vm: VisitEditViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        mode: VisitEditViewModel.Mode,
        repository: any VisitRepository,
        calendarRepository: (any CalendarRepository)? = nil
    ) {
        _vm = State(wrappedValue: VisitEditViewModel(
            mode: mode,
            repository: repository,
            calendarRepository: calendarRepository
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Doctor") {
                    TextField("Doctor name", text: $vm.doctorName)
                        .autocorrectionDisabled()
                    TextField("Specialty", text: $vm.specialty)
                        .autocorrectionDisabled()
                }
                Section("Visit") {
                    DatePicker("Date & Time", selection: $vm.visitAt, displayedComponents: [.date, .hourAndMinute])
                    TextField("Location", text: $vm.location)
                        .autocorrectionDisabled()
                }
                Section("Clinical") {
                    TextField("Diagnosis", text: $vm.diagnosis, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Recommendations", text: $vm.recommendations, axis: .vertical)
                        .lineLimit(3...6)
                }
                if case .failed(let error) = vm.saveState {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(vm.mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await vm.save() }
                    }
                    .disabled(vm.saveState == .saving)
                }
            }
            .onChange(of: vm.saveState) { _, newState in
                if newState == .saved { dismiss() }
            }
        }
    }
}

#Preview("Create") {
    VisitEditView(
        mode: .create,
        repository: PreviewVisitRepository()
    )
}

#Preview("Edit") {
    let visits = PreviewVisitRepository.makeSampleVisits()
    VisitEditView(
        mode: .edit(visits[0]),
        repository: PreviewVisitRepository(visits: visits)
    )
}
