import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case peach          // デフォルト (ピーチ / コーラル) — 女性向け
    case sky            // スカイ (ブルー / ネイビー) — 男性向け
    case midnight       // ミッドナイト (ダーク) — 暗め
    case sunshine       // サンシャイン (イエロー / オレンジ) — 黄色系
    case forest         // フォレスト (グリーン / アース) — 自然系

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .peach: "ピーチ"
        case .sky: "スカイ"
        case .midnight: "ミッドナイト"
        case .sunshine: "サンシャイン"
        case .forest: "フォレスト"
        }
    }

    var hint: String {
        switch self {
        case .peach: "やわらかピーチ&コーラル"
        case .sky: "クールなブルー系"
        case .midnight: "目に優しい暗め配色"
        case .sunshine: "明るく元気な黄色系"
        case .forest: "落ち着きのある自然系"
        }
    }

    // MARK: - Color tokens

    var background: Color {
        switch self {
        case .peach: Color(red: 1.00, green: 0.97, blue: 0.93)
        case .sky: Color(red: 0.94, green: 0.97, blue: 1.00)
        case .midnight: Color(red: 0.10, green: 0.11, blue: 0.14)
        case .sunshine: Color(red: 1.00, green: 0.98, blue: 0.90)
        case .forest: Color(red: 0.95, green: 0.97, blue: 0.93)
        }
    }

    var surface: Color {
        switch self {
        case .peach: Color(red: 1.00, green: 0.99, blue: 0.96)
        case .sky: Color(red: 1.00, green: 1.00, blue: 1.00)
        case .midnight: Color(red: 0.17, green: 0.18, blue: 0.22)
        case .sunshine: Color(red: 1.00, green: 1.00, blue: 0.96)
        case .forest: Color(red: 1.00, green: 1.00, blue: 0.98)
        }
    }

    var primary: Color {
        switch self {
        case .peach: Color(red: 1.00, green: 0.62, blue: 0.55)
        case .sky: Color(red: 0.36, green: 0.62, blue: 0.92)
        case .midnight: Color(red: 0.65, green: 0.78, blue: 1.00)
        case .sunshine: Color(red: 1.00, green: 0.78, blue: 0.30)
        case .forest: Color(red: 0.42, green: 0.66, blue: 0.52)
        }
    }

    var primaryDeep: Color {
        switch self {
        case .peach: Color(red: 0.84, green: 0.33, blue: 0.30)
        case .sky: Color(red: 0.18, green: 0.40, blue: 0.78)
        case .midnight: Color(red: 0.45, green: 0.62, blue: 0.95)
        case .sunshine: Color(red: 0.85, green: 0.58, blue: 0.12)
        case .forest: Color(red: 0.22, green: 0.50, blue: 0.32)
        }
    }

    var secondary: Color {
        switch self {
        case .peach: Color(red: 0.96, green: 0.85, blue: 0.74)
        case .sky: Color(red: 0.78, green: 0.88, blue: 0.98)
        case .midnight: Color(red: 0.30, green: 0.34, blue: 0.42)
        case .sunshine: Color(red: 0.98, green: 0.90, blue: 0.70)
        case .forest: Color(red: 0.82, green: 0.92, blue: 0.84)
        }
    }

    var textPrimary: Color {
        switch self {
        case .peach: Color(red: 0.30, green: 0.25, blue: 0.20)
        case .sky: Color(red: 0.16, green: 0.20, blue: 0.30)
        case .midnight: Color(red: 0.95, green: 0.95, blue: 0.97)
        case .sunshine: Color(red: 0.35, green: 0.28, blue: 0.12)
        case .forest: Color(red: 0.18, green: 0.26, blue: 0.20)
        }
    }

    var textSecondary: Color {
        switch self {
        case .peach: Color(red: 0.54, green: 0.47, blue: 0.39)
        case .sky: Color(red: 0.40, green: 0.46, blue: 0.55)
        case .midnight: Color(red: 0.70, green: 0.72, blue: 0.78)
        case .sunshine: Color(red: 0.55, green: 0.48, blue: 0.32)
        case .forest: Color(red: 0.42, green: 0.50, blue: 0.42)
        }
    }

    var success: Color {
        switch self {
        case .peach: Color(red: 0.55, green: 0.78, blue: 0.55)
        case .sky: Color(red: 0.36, green: 0.78, blue: 0.66)
        case .midnight: Color(red: 0.40, green: 0.85, blue: 0.65)
        case .sunshine: Color(red: 0.60, green: 0.80, blue: 0.40)
        case .forest: Color(red: 0.45, green: 0.74, blue: 0.48)
        }
    }

    var restDay: Color {
        switch self {
        case .peach: Color(red: 0.70, green: 0.80, blue: 0.95)
        case .sky: Color(red: 0.60, green: 0.78, blue: 0.95)
        case .midnight: Color(red: 0.45, green: 0.55, blue: 0.78)
        case .sunshine: Color(red: 0.78, green: 0.84, blue: 0.95)
        case .forest: Color(red: 0.70, green: 0.85, blue: 0.90)
        }
    }

    var missed: Color {
        switch self {
        case .peach: Color(red: 0.86, green: 0.47, blue: 0.45)
        case .sky: Color(red: 0.85, green: 0.55, blue: 0.55)
        case .midnight: Color(red: 0.95, green: 0.45, blue: 0.55)
        case .sunshine: Color(red: 0.88, green: 0.50, blue: 0.30)
        case .forest: Color(red: 0.78, green: 0.50, blue: 0.45)
        }
    }

    var historyAccent: Color {
        switch self {
        case .peach: Color(red: 0.62, green: 0.49, blue: 0.86)
        case .sky: Color(red: 0.45, green: 0.58, blue: 0.85)
        case .midnight: Color(red: 0.75, green: 0.60, blue: 0.92)
        case .sunshine: Color(red: 0.85, green: 0.55, blue: 0.45)
        case .forest: Color(red: 0.55, green: 0.65, blue: 0.45)
        }
    }

    var settingsAccent: Color {
        switch self {
        case .peach: Color(red: 0.36, green: 0.62, blue: 0.72)
        case .sky: Color(red: 0.30, green: 0.55, blue: 0.78)
        case .midnight: Color(red: 0.55, green: 0.70, blue: 0.85)
        case .sunshine: Color(red: 0.65, green: 0.55, blue: 0.40)
        case .forest: Color(red: 0.45, green: 0.62, blue: 0.55)
        }
    }

    var chipBackground: Color {
        switch self {
        case .peach: Color(red: 1.00, green: 0.91, blue: 0.86)
        case .sky: Color(red: 0.88, green: 0.94, blue: 1.00)
        case .midnight: Color(red: 0.22, green: 0.25, blue: 0.32)
        case .sunshine: Color(red: 1.00, green: 0.94, blue: 0.78)
        case .forest: Color(red: 0.92, green: 0.96, blue: 0.88)
        }
    }

    func categoryColor(for category: WorkoutCategory) -> Color {
        switch category {
        case .cardio: Color(red: 0.36, green: 0.62, blue: 0.72)
        case .strength: primaryDeep
        case .yoga: Color(red: 0.58, green: 0.55, blue: 0.82)
        case .stretch: Color(red: 0.42, green: 0.66, blue: 0.52)
        case .fasciaRelease: Color(red: 0.85, green: 0.55, blue: 0.40)
        case .other: historyAccent
        }
    }

    /// Preferred system color scheme for this theme — lets SwiftUI switch
    /// default control tints to a sensible default.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .midnight: return .dark
        default: return .light
        }
    }
}
