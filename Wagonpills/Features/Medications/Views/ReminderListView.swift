import SwiftUI

struct ReminderListView: View {
    @State private var vm: ReminderListViewModel
    @State private var showCreateSheet = false
    @State private var editingRule: ReminderRule?
    @State private var ruleToDelete: ReminderRule?
    @Environment(\.notificationRescheduler) private var notificationRescheduler

    init(viewModel: ReminderListViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let rules):
                ruleList(rules)
            case .empty:
                emptyState
            case .failed(let error):
                errorView(error)
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.refresh() }
        .sheet(
            isPresented: $showCreateSheet,
            onDismiss: { Task { await vm.refresh() } },
            content: {
                ReminderRuleEditView(viewModel: ReminderRuleEditViewModel(
                    mode: .create,
                    medicationId: vm.medicationId,
                    repository: vm.repository,
                    notificationRescheduler: notificationRescheduler
                ))
            }
        )
        .sheet(
            item: $editingRule,
            onDismiss: { Task { await vm.refresh() } },
            content: { rule in
                ReminderRuleEditView(viewModel: ReminderRuleEditViewModel(
                    mode: .edit(rule),
                    medicationId: vm.medicationId,
                    repository: vm.repository,
                    notificationRescheduler: notificationRescheduler
                ))
            }
        )
        .confirmationDialog(
            "Delete reminder rule?",
            isPresented: Binding(
                get: { ruleToDelete != nil },
                set: { if !$0 { ruleToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let rule = ruleToDelete {
                Button("Delete", role: .destructive) {
                    Task {
                        await vm.delete(rule: rule)
                        ruleToDelete = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) { ruleToDelete = nil }
        } message: {
            Text("This will also remove all associated times.")
        }
    }

    // MARK: - Subviews

    private func ruleList(_ rules: [ReminderRule]) -> some View {
        List {
            ForEach(rules) { rule in
                Button { editingRule = rule } label: {
                    ReminderRuleRow(rule: rule)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { ruleToDelete = rule } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No reminder rules yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button("Add Rule") { showCreateSheet = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: APIError) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Could not load reminders",
                systemImage: "wifi.slash",
                description: Text(error.localizedDescription)
            )
            Button("Retry") { Task { await vm.load() } }
                .buttonStyle(.bordered)
        }
    }
}

// MARK: - Rule Row

private struct ReminderRuleRow: View {
    let rule: ReminderRule

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(repeatLabel)
                    .font(.body)
                Spacer()
                if !rule.active {
                    Text("Inactive")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            if !rule.times.isEmpty {
                Text(timesLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private var repeatLabel: String {
        switch rule.repeatType {
        case .daily:
            return String(localized: "Daily")
        case .weekly:
            let days = rule.daysOfWeek.sorted().map(\.displayName).joined(separator: ", ")
            return String(localized: "Weekly: \(days)")
        case .interval:
            let days = rule.intervalDays ?? 1
            return String(localized: "Every \(days) day(s)")
        }
    }

    private var timesLabel: String {
        rule.times.map(\.displayString).sorted().joined(separator: ", ")
    }
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        ReminderListView(viewModel: ReminderListViewModel(
            medicationId: 1,
            repository: PreviewReminderRepository(rules: PreviewReminderRepository.makePreviewRules())
        ))
    }
}

#Preview("Empty") {
    NavigationStack {
        ReminderListView(viewModel: ReminderListViewModel(
            medicationId: 1,
            repository: PreviewReminderRepository(rules: [])
        ))
    }
}
