import SwiftUI

struct CalendarView: View {
    @State private var vm: CalendarViewModel
    @State private var showingCreate = false
    @State private var eventToDelete: CalendarEvent?
    @State private var showDeleteAlert = false

    private let scheduler: any NotificationScheduler

    init(viewModel: CalendarViewModel, scheduler: any NotificationScheduler = LiveNotificationScheduler()) {
        _vm = State(wrappedValue: viewModel)
        self.scheduler = scheduler
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                weekdayLabels
                Divider()
                monthGrid
                Divider()
                selectedDayEvents
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(
                isPresented: $showingCreate,
                onDismiss: { Task { await vm.refresh() } },
                content: {
                    CalendarEventEditView(
                        viewModel: CalendarEventEditViewModel(
                            mode: .create,
                            repository: vm.repository,
                            visitRepository: vm.visitRepository,
                            initialDate: vm.selectedDate
                        )
                    )
                }
            )
            .alert("Delete Event?", isPresented: $showDeleteAlert, presenting: eventToDelete) { event in
                Button("Delete", role: .destructive) {
                    Task { await vm.delete(event) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { event in
                Text("Delete \"\(event.title)\"?")
            }
            .alert(
                "Could Not Delete Event",
                isPresented: Binding(get: { vm.deleteError != nil }, set: { if !$0 { vm.clearDeleteError() } }),
                presenting: vm.deleteError
            ) { _ in
                Button("OK", role: .cancel) { vm.clearDeleteError() }
            } message: { error in
                Text(error.localizedDescription)
            }
            .task { await vm.load() }
        }
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack {
            Button(action: vm.previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding(8)
            }
            Spacer()
            Text(vm.selectedMonth, format: .dateTime.month(.wide).year())
                .font(.title3.bold())
            Spacer()
            Button(action: vm.nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .padding(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Weekday labels

    private var weekdayLabels: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let reordered = reorderedWeekdays(symbols)
        return HStack(spacing: 0) {
            ForEach(Array(reordered.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        let gridDays = CalendarGridHelper.days(for: vm.selectedMonth)
        let datesWithEvents = vm.datesWithEvents

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let date = day {
                    DayCellView(
                        date: date,
                        isSelected: vm.selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: vm.selectedMonth, toGranularity: .month),
                        hasEvents: datesWithEvents.contains(Calendar.current.startOfDay(for: date))
                    )
                    .onTapGesture {
                        vm.selectedDate = Calendar.current.isDate(
                            date, equalTo: vm.selectedMonth, toGranularity: .month
                        ) ? date : nil
                    }
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    // MARK: - Selected day events

    @ViewBuilder
    private var selectedDayEvents: some View {
        if let selectedDate = vm.selectedDate {
            let dayEvents = vm.eventsForSelectedDate
            if dayEvents.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(selectedDate, format: .dateTime.day().month(.wide))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(dayEvents) { event in
                        NavigationLink(destination: eventDetail(for: event)) {
                            CalendarEventRowView(event: event)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                eventToDelete = event
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        } else {
            Text("Select a day to see events")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func eventDetail(for event: CalendarEvent) -> some View {
        CalendarEventDetailView(
            viewModel: CalendarEventDetailViewModel(
                eventId: event.id,
                repository: vm.repository,
                scheduler: scheduler,
                visitRepository: vm.visitRepository
            )
        )
    }

    // MARK: - Helpers

    private func reorderedWeekdays(_ symbols: [String]) -> [String] {
        let firstWeekday = Calendar.current.firstWeekday - 1
        guard firstWeekday > 0 else { return symbols }
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }
}

// MARK: - Day Cell

private struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let hasEvents: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(date, format: .dateTime.day())
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isSelected ? Color.white : isCurrentMonth ? Color.primary : Color.secondary.opacity(0.5))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : isToday ? Color.accentColor.opacity(0.15) : .clear,
                            in: Circle())
            Circle()
                .fill(isSelected ? Color.white.opacity(0.8) : Color.accentColor)
                .frame(width: 5, height: 5)
                .opacity(hasEvents ? 1 : 0)
        }
        .frame(height: 48)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Calendar grid helper

enum CalendarGridHelper {
    static func days(for month: Date) -> [Date?] {
        let cal = Calendar.current
        guard
            let monthRange = cal.range(of: .day, in: .month, for: month),
            let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: month))
        else { return [] }

        let weekday = cal.component(.weekday, from: firstDay)
        let firstWeekday = cal.firstWeekday
        let offset = (weekday - firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for dayIndex in 1...monthRange.count {
            let date = cal.date(byAdding: .day, value: dayIndex - 1, to: firstDay)
            days.append(date)
        }

        let remainder = days.count % 7
        if remainder != 0 {
            days += Array(repeating: nil, count: 7 - remainder)
        }
        return days
    }
}

// MARK: - Previews

#Preview("Loaded") {
    CalendarView(
        viewModel: CalendarViewModel(
            repository: PreviewCalendarRepository(),
            visitRepository: PreviewVisitRepository()
        ),
        scheduler: PreviewNotificationScheduler()
    )
}

#Preview("Empty") {
    CalendarView(
        viewModel: CalendarViewModel(
            repository: PreviewCalendarRepository(events: []),
            visitRepository: PreviewVisitRepository(visits: [])
        ),
        scheduler: PreviewNotificationScheduler()
    )
}

#Preview("Error") {
    CalendarView(
        viewModel: CalendarViewModel(
            repository: PreviewCalendarRepository(events: [], error: .network),
            visitRepository: PreviewVisitRepository()
        ),
        scheduler: PreviewNotificationScheduler()
    )
}
