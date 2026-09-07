import CoreGraphics

/// The corner-radius scale (Design System §4).
///
/// Before this, 12, 13, 14, and 20 all appeared across the app with no rule
/// behind which was used where. Radius is a hierarchy signal — a control, a
/// row, and a card should not look equally "carved" — so it needs a scale
/// rather than per-view guesses.
enum CornerRadius {
    /// Inline controls and compact chips: set rows, date badges.
    static let small: CGFloat = 12
    /// Secondary containers: collapsed rows, banners, stat tiles.
    static let medium: CGFloat = 16
    /// Cards. Fixed by Design System §4.
    static let card: CGFloat = 20
}
