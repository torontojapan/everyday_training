import SwiftUI

struct CatMessageView: View {
    let message: CatMessage
    let state: CatState

    init(message: CatMessage, state: CatState = .waitingMorning) {
        self.message = message
        self.state = state
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CatStateView(state: state)

            // 引用符を外し本文だけにすることで吹き出し感を維持しつつ
            // 視覚的なノイズを減らす。本文は最大 3 行で省略。
            Text(message.text)
                .font(Typography.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
                .padding(16)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .leading) {
                    Triangle()
                        .fill(Palette.surface)
                        .frame(width: 14, height: 16)
                        .offset(x: -9)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
