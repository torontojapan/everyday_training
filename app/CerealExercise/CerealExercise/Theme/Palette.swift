import SwiftUI

@MainActor
enum Palette {
    private static var theme: AppTheme { ThemeStore.shared.theme }

    static var background: Color { theme.background }
    static var surface: Color { theme.surface }
    static var primary: Color { theme.primary }
    static var primaryDeep: Color { theme.primaryDeep }
    static var secondary: Color { theme.secondary }
    static var textPrimary: Color { theme.textPrimary }
    static var textSecondary: Color { theme.textSecondary }
    static var success: Color { theme.success }
    static var restDay: Color { theme.restDay }
    static var missed: Color { theme.missed }
    static var historyAccent: Color { theme.historyAccent }
    static var settingsAccent: Color { theme.settingsAccent }
    static var chipBackground: Color { theme.chipBackground }

    static func categoryColor(for category: WorkoutCategory) -> Color {
        theme.categoryColor(for: category)
    }
}
