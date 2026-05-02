import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pills.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            Text("WagonPills")
                .font(.largeTitle)
                .fontWeight(.semibold)

            ProgressView()
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    SplashView()
}
