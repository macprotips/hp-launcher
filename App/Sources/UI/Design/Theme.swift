import SwiftUI

/// Colours and type for the "After Dark" design (docs/Design.md).
enum Theme {
    static let gold = Color(red: 0.87, green: 0.72, blue: 0.43)
    static let candle = Color(red: 1.0, green: 0.80, blue: 0.48)
    static let ink = Color(red: 0.95, green: 0.95, blue: 0.93)
    static let secondaryInk = Color.white.opacity(0.74)

    /// Optima ships with macOS, so nothing is bundled.
    static func display(_ size: CGFloat) -> Font { .custom("Optima", size: size) }
}
