import SwiftUI

/// Home banner shown when an in-progress session exists (D-029).
/// Tap taps into Active Workout on that session via the `onResume` callback.
struct ResumeBanner: View {
    let session: Session
    let onResume: () -> Void

    private var timeAgo: String {
        let seconds = Date().timeIntervalSince(session.startedAt)
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) h ago" }
        let days = hours / 24
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }

    var body: some View {
        Button {
            Haptics.resumeTapped()
            onResume()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Resume workout")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Started \(timeAgo)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
    }
}
