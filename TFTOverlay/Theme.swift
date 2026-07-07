import SwiftUI

/// Notion-dark, tuned for an overlay that sits over a game:
/// translucent paper, quiet ink, tier colors that read at a glance.
enum Theme {
    static let paper = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let ink = Color(red: 0.93, green: 0.93, blue: 0.92)
    static let secondary = Color(red: 0.61, green: 0.61, blue: 0.59)
    static let divider = Color.white.opacity(0.08)
    static let fill = Color.white.opacity(0.06)

    static func tierColor(_ tier: String) -> Color {
        switch tier {
        case "S": return Color(red: 1.00, green: 0.49, blue: 0.51)
        case "A": return Color(red: 1.00, green: 0.72, blue: 0.42)
        case "B": return Color(red: 0.98, green: 0.89, blue: 0.55)
        case "C": return Color(red: 0.66, green: 0.66, blue: 0.64)
        default: return Color(red: 0.45, green: 0.45, blue: 0.44)
        }
    }

    /// TFT cost colors for the shop-odds table (1..5 cost).
    static let costColors: [Color] = [
        Color(red: 0.63, green: 0.63, blue: 0.63),
        Color(red: 0.36, green: 0.80, blue: 0.44),
        Color(red: 0.35, green: 0.62, blue: 0.98),
        Color(red: 0.78, green: 0.44, blue: 0.94),
        Color(red: 1.00, green: 0.72, blue: 0.25),
    ]
}
