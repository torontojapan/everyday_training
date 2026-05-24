import SwiftUI

struct MilestoneCelebrationSheet: View {
    let milestone: Milestone
    @Binding var isPresented: Bool
    var onAcknowledge: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 1.00, green: 0.85, blue: 0.40),
                         Color(red: 1.00, green: 0.55, blue: 0.55),
                         Color(red: 0.85, green: 0.45, blue: 0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ConfettiView()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 80)
                    Text(milestone.emoji)
                        .font(.system(size: 96))
                    Text(milestone.headline)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(milestone.detail)
                        .font(Typography.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    PrimaryButton("受け取る", systemImage: "sparkles") {
                        onAcknowledge()
                        isPresented = false
                        dismiss()
                    }
                    .padding(.top, 12)
                    Spacer().frame(height: 60)
                }
                .padding(24)
            }

            HStack {
                Spacer()
                Button {
                    onAcknowledge()
                    isPresented = false
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .padding(.top, 12)
                .padding(.trailing, 16)
                .accessibilityLabel("閉じる")
            }
        }
    }
}
