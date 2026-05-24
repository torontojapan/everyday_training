import SwiftUI

struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    private let hapticFeedback: any HapticFeedbackProviding
    @GestureState private var isPressed = false

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
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(title)
        .scaleEffect(isPressed ? 0.96 : 1)
        .animation(Motion.snappy, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
    }
}
