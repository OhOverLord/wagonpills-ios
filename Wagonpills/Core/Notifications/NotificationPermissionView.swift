import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .padding(.bottom, 28)

            Text("Get Medication Reminders")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text("We'll notify you when it's time to take your medication")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    isRequesting = true
                    Task {
                        _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound, .badge])
                        isRequesting = false
                        dismiss()
                    }
                } label: {
                    Group {
                        if isRequesting {
                            ProgressView()
                        } else {
                            Text("Allow Notifications")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequesting)
                .padding(.horizontal, 32)

                Button("Not Now") { dismiss() }
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    NotificationPermissionView()
}
