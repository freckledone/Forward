import SwiftUI

/// The one control that begins a workout.
///
/// Reads as a button through *shape* rather than saturation: a lightly tinted
/// fill inside a defined accent ring. A solid accent disc was unambiguous but
/// shouted — on a list of cards that each already carry a muscle tint, several
/// filled accent circles fight both the tints and each other.
///
/// The press animation is feedback, not a gate. It fires alongside the start,
/// never before it: making a tap wait on an animation trades responsiveness
/// for polish, and on the one control that begins a workout that is the wrong
/// way round.
struct StartButton: View {
    let action: () -> Void

    @State private var didPress = false

    @ScaledMetric(relativeTo: .title2) private var diameter: CGFloat = 54
    @ScaledMetric(relativeTo: .title2) private var glyph: CGFloat = 22

    var body: some View {
        Button {
            Haptics.resumeTapped()
            didPress.toggle()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1.5)

                Image(systemName: "play.fill")
                    .font(.system(size: glyph, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    // play.fill's visual mass sits left of its glyph box.
                    .offset(x: 2)
                    .symbolEffect(.bounce, value: didPress)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(.startsMediaSession)
    }
}

/// Presses shrink slightly. Without it the button gives no sign it was hit
/// until the next screen arrives.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
