import UIKit

enum HapticFeedbackEvent: Equatable, Sendable {
    case success
    case warning
    case tap
}

@MainActor
protocol HapticFeedbackProviding: AnyObject {
    func success()
    func warning()
    func tap()
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
}
