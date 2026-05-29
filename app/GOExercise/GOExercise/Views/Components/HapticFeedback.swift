import UIKit

enum HapticFeedbackEvent: Equatable, Sendable {
    case success
    case warning
    case tap
    case heroic        // 3 段階パルス: heavy → rigid → success
    case milestone     // legendary パターン: 5 連鎖
}

@MainActor
protocol HapticFeedbackProviding: AnyObject {
    func success()
    func warning()
    func tap()
    func heroic()
    func milestone()
}

@MainActor
final class HapticFeedback: HapticFeedbackProviding {
    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
    }

    func heroic() {
        // Double-impact + success: 「ドン・ドン・ピロン」感
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred(intensity: 1.0)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.85)
            try? await Task.sleep(for: .milliseconds(130))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func milestone() {
        // 5 連打 + 最後にレベルアップ感の success
        Task { @MainActor in
            for i in 0..<4 {
                let style: UIImpactFeedbackGenerator.FeedbackStyle = i.isMultiple(of: 2) ? .medium : .rigid
                UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: 0.7 + Double(i) * 0.1)
                try? await Task.sleep(for: .milliseconds(120))
            }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
            try? await Task.sleep(for: .milliseconds(160))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

@MainActor
final class HapticFeedbackController {
    private let provider: any HapticFeedbackProviding

    init(provider: any HapticFeedbackProviding = HapticFeedback()) {
        self.provider = provider
    }

    func success() {
        provider.success()
    }

    func warning() {
        provider.warning()
    }

    func tap() {
        provider.tap()
    }

    func heroic() {
        provider.heroic()
    }

    func milestone() {
        provider.milestone()
    }
}
