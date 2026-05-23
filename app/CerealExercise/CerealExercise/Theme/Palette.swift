import SwiftUI

enum Palette {
    static let background = Color(red: 1.00, green: 0.97, blue: 0.93)
    static let surface = Color(red: 1.00, green: 0.99, blue: 0.96)
    static let primary = Color(red: 1.00, green: 0.62, blue: 0.55)
    static let primaryDeep = Color(red: 0.84, green: 0.33, blue: 0.30)
    static let secondary = Color(red: 0.96, green: 0.85, blue: 0.74)
    static let textPrimary = Color(red: 0.30, green: 0.25, blue: 0.20)
    static let textSecondary = Color(red: 0.54, green: 0.47, blue: 0.39)
    static let success = Color(red: 0.55, green: 0.78, blue: 0.55)
    static let restDay = Color(red: 0.70, green: 0.80, blue: 0.95)
    static let missed = Color(red: 0.86, green: 0.47, blue: 0.45)
    static let historyAccent = Color(red: 0.62, green: 0.49, blue: 0.86)
    static let settingsAccent = Color(red: 0.36, green: 0.62, blue: 0.72)
    static let chipBackground = Color(red: 1.00, green: 0.91, blue: 0.86)

    static func categoryColor(for category: WorkoutCategory) -> Color {
        switch category {
        case .cardio: Color(red: 0.36, green: 0.62, blue: 0.72)
        case .strength: primaryDeep
        case .yoga: Color(red: 0.58, green: 0.55, blue: 0.82)
        case .stretch: Color(red: 0.42, green: 0.66, blue: 0.52)
        case .other: historyAccent
        }
    }
}
