import SwiftUI

struct IntakeHistoryView: View {
    @State private var vm: IntakeHistoryViewModel
    @State private var showDateFilter = false

    init(viewModel: IntakeHistoryViewModel) {
        _vm = State(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch vm.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                emptyView
            case .failed(let error):
                errorView(error)
            case .loaded:
                loadedView
            }
        }
        .navigationTitle("Intake History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .task { await vm.load() }
        .onChange(of: vm.statusFilter) { Task { await vm.load() } }
        .onChange(of: vm.fromDate) { Task { await vm.load() } }
        .onChange(of: vm.toDate) { Task { await vm.load() } }
    }

    // MARK: - Loaded content

    private var loadedView: some View {
        List {
            adherenceSummarySection
            dateFilterSection
            statusPickerSection
            logSections
        }
        .listStyle(.insetGrouped)
    }

    private var adherenceSummarySection: some View {
        Section {
            if let summary = vm.adherenceSummary {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last 30 days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(summary.taken)/\(summary.total) taken")
                            .font(.title3.bold())
                    }
                    Spacer()
                    adherenceGauge(taken: summary.taken, total: summary.total)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func adherenceGauge(taken: Int, total: Int) -> some View {
        let percent = total > 0 ? Double(taken) / Double(total) : 0
        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: percent)
                .stroke(gaugeColor(percent), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(percent * 100))%")
                .font(.caption2.bold())
        }
        .frame(width: 56, height: 56)
    }

    private func gaugeColor(_ percent: Double) -> Color {
        if percent >= 0.8 { return .green }
        if percent >= 0.5 { return .yellow }
        return .red
    }

    private var statusPickerSection: some View {
        Section {
            Picker("Status", selection: $vm.statusFilter) {
                Text("All").tag(IntakeStatus?.none)
                Text("Taken").tag(IntakeStatus?.some(.taken))
                Text("Skipped").tag(IntakeStatus?.some(.skipped))
                Text("Missed").tag(IntakeStatus?.some(.missed))
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var dateFilterSection: some View {
        Section {
            DisclosureGroup("Date Range", isExpanded: $showDateFilter) {
                let today = Calendar.current.startOfDay(for: Date())
                DatePicker("From", selection: $vm.fromDate, in: ...today, displayedComponents: .date)
                DatePicker("To", selection: $vm.toDate, in: vm.fromDate...today, displayedComponents: .date)
            }
        }
    }

    @ViewBuilder
    private var logSections: some View {
        ForEach(vm.logsByDay, id: \.day) { group in
            Section(header: Text(group.day, style: .date)) {
                ForEach(group.logs) { log in
                    IntakeLogRow(log: log)
                }
            }
        }
    }

    // MARK: - Empty / error

    private var emptyView: some View {
        List {
            dateFilterSection
            statusPickerSection
            Section {
                ContentUnavailableView(
                    "No Records",
                    systemImage: "list.bullet.clipboard",
                    description: Text("No intake logs found for the selected period.")
                )
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func errorView(_ error: APIError) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Could not load history",
                systemImage: "wifi.slash",
                description: Text(error.localizedDescription)
            )
            Button("Retry") {
                Task { await vm.load() }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if vm.state == .loading {
                ProgressView()
            }
        }
    }
}

// MARK: - Log row

private struct IntakeLogRow: View {
    let log: IntakeLog

    var body: some View {
        HStack(spacing: 12) {
            Text(log.scheduledTime, format: .dateTime.hour().minute())
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            statusBadge

            if let note = log.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption.bold())
            Text(log.status.displayName)
                .font(.subheadline)
        }
        .foregroundStyle(statusColor)
    }

    private var statusIcon: String {
        switch log.status {
        case .taken:   return "checkmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case .missed:  return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch log.status {
        case .taken:   return .green
        case .skipped: return .secondary
        case .missed:  return .red
        }
    }
}

// MARK: - Helpers

private extension IntakeStatus {
    var displayName: String {
        switch self {
        case .taken:   return String(localized: "Taken")
        case .skipped: return String(localized: "Skipped")
        case .missed:  return String(localized: "Missed")
        }
    }
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        IntakeHistoryView(viewModel: {
            let vm = IntakeHistoryViewModel(
                medicationId: 1,
                repository: PreviewIntakeLogRepository(logs: PreviewIntakeLogRepository.makeSampleLogs())
            )
            return vm
        }())
    }
}

#Preview("Empty") {
    NavigationStack {
        IntakeHistoryView(viewModel: IntakeHistoryViewModel(
            medicationId: 1,
            repository: PreviewIntakeLogRepository(logs: [])
        ))
    }
}

#Preview("Error") {
    NavigationStack {
        IntakeHistoryView(viewModel: IntakeHistoryViewModel(
            medicationId: 1,
            repository: PreviewIntakeLogRepository(error: .server(status: 500))
        ))
    }
}
