import SwiftUI

struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    private let hapticFeedback: any HapticFeedbackProviding

    init(
        _ title: String,
        systemImage: String? = nil,
        hapticFeedback: any HapticFeedbackProviding = HapticFeedback(),
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.hapticFeedback = hapticFeedback
        self.action = action
    }

    var body: some View {
        Button {
            hapticFeedback.tap()
            action()
        } label: {
            Label(title, systemImage: systemImage ?? "checkmark.circle.fill")
                .font(Typography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Palette.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier(title)
    }
}

/// Use the ButtonStyle's own isPressed signal instead of a
/// DragGesture(minimumDistance: 0). The drag gesture variant intercepts
/// scroll views and forms, making them feel sluggish; ButtonStyle is the
/// native SwiftUI way to react to press state.
struct PressableScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}
