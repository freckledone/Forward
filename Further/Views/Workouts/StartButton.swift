import SwiftUI

/// The one control that begins a workout.
///
/// Solid accent fill with a white glyph rather than the tinted circle it used
/// to be: a 12%-tinted icon reads as an ornament on a card, and this needs to
/// read as the button. It is the only thing on Home you can actually press.
///
/// Pressing runs a short confirmation beat — the circle swells, the glyph
/// bounces — before the workout screen takes over. The delay is 180ms, under
/// the threshold where a transition starts to feel sluggish, and it exists so
/// the press registers as *"started"* rather than the screen simply changing.
struct StartButton: View {
    let action: () -> Void

    @State private var isStarting = false

    @ScaledMetric(relativeTo: .title2) private var diameter: CGFloat = 56
    @ScaledMetric(relativeTo: .title2) private var glyph: CGFloat = 24

    var body: some View {
        Button {
            guard !isStarting else { return }   // double-taps must not start twice
            Haptics.resumeTapped()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                isStarting = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                action()
                isStarting = false
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 8, y: 3)

                Image(systemName: "play.fill")
                    .font(.system(size: glyph, weight: .bold))
                    .foregroundStyle(.white)
                    // play.fill's visual mass sits left of its glyph box.
                    .offset(x: 2)
                    .symbolEffect(.bounce, value: isStarting)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(isStarting ? 1.12 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(.startsMediaSession)
    }
}

/// Presses shrink slightly. Without it a filled circle gives no sign it was
/// hit until the next screen arrives.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
