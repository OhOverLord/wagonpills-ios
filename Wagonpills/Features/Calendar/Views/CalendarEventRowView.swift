import SwiftUI

struct CalendarEventRowView: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.systemImage)
                .foregroundStyle(event.type.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .strikethrough(event.isCancelled)
                        .foregroundStyle(event.isCancelled ? .secondary : .primary)

                    if event.isCancelled {
                        Text("Cancelled")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                    }
                }

                Text(event.startsAt, format: .dateTime.hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !event.reminders.isEmpty {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        CalendarEventRowView(event: PreviewCalendarRepository.sampleEvents[0])
        CalendarEventRowView(event: PreviewCalendarRepository.sampleEvents[2])
    }
}
