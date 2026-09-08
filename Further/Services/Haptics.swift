import UIKit

/// Named-intent haptic feedback per `docs/04-design-system.md` §10.
///
/// Callers say `Haptics.setCompleted()`, not `Haptics.rigidImpact()`. If we
/// later decide a moment feels wrong at its current intensity, one change
/// here updates every call site.
///
/// Every method respects the user's system-wide "System Haptics" setting
/// automatically via the underlying UIKit generators.
enum Haptics {

    // MARK: - Per-set (frequent, soft)

    static func setCompleted() { impact(.rigid) }
    static func setSkipped()   { impact(.soft) }
    static func setAdded()     { impact(.light) }

    static func starToggled() {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }

    // MARK: - Session boundaries (rare, stronger)

    static func workoutStarted() { impact(.medium) }
    static func workoutEnded()   { impact(.medium) }
    static func resumeTapped()   { impact(.light) }

    // MARK: - Notification-style

    static func personalRecordEarned() { notification(.success) }
    static func warning()              { notification(.warning) }

    // MARK: - Internals

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }

    private static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }
}
