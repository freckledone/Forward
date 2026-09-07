import SwiftUI

/// The app icon's palette, available to the UI.
///
/// Sampled from `Icon-iOS-Default-1024x1024@1x.png` rather than eyeballed, so
/// the app and its icon are demonstrably the same object. The icon reads as a
/// dark charcoal that warms into steel blue toward the bottom, with pale
/// blue-white artwork on top.
enum Brand {

    /// Icon background gradient, dark end to blue end.
    static let deepCharcoal = Color(red: 0.106, green: 0.122, blue: 0.137)  // #1B1F23
    static let midnight     = Color(red: 0.106, green: 0.165, blue: 0.227)  // #1B2A3A
    static let steel        = Color(red: 0.075, green: 0.200, blue: 0.337)  // #133356
    static let deepBlue     = Color(red: 0.063, green: 0.227, blue: 0.408)  // #103A68

    /// Icon artwork, palest first.
    static let iceWhite     = Color(red: 0.929, green: 0.949, blue: 0.980)  // #EDF2FA
    static let paleBlue     = Color(red: 0.659, green: 0.737, blue: 0.827)  // #A8BCD3

    /// The icon's own gradient, for hero surfaces that should feel like the
    /// app's cover: the End Workout summary, a future launch screen.
    static let iconGradient = LinearGradient(
        colors: [deepCharcoal, midnight, steel, deepBlue],
        startPoint: .top,
        endPoint: .bottom
    )
}
