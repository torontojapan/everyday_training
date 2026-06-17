import SwiftUI

/// 共有/保存画像のキャンバスサイズ。スマホ全画面とほぼ同じ縦長比率 (9:19.5) にして、
/// 「写真に保存」した画像がスマホでフルサイズ表示される(上下に黒帯が出ない)ようにする。
/// 全カード (連続/今週/今月/これまで) の `renderImage()` がこのサイズで書き出す。
/// fillFrame と併用してグラデを隅まで塗るのが前提。
enum ShareCardLayout {
    static let canvas = CGSize(width: 600, height: 1300)
}

/// 共有カード(ホーム連続/今週/先月/これまで)の背景グラデーション・プリセット(5種)。
/// 既存4カードの配色をプリセット化して全カードで相互選択できるようにし、緑系を1つ追加。
/// 選択は各シートの「写真に保存」下の○ピッカーで行い、@AppStorage にカード種別ごとに保存する。
enum ShareCardGradient: String, CaseIterable, Identifiable {
    case sunset      // 暖色(旧: 今週のハイライト既定)
    case ocean       // 寒色(旧: ホーム連続カード既定)
    case twilight    // 紫(旧: 先月レビュー既定)
    case forest      // 緑(新規)
    case daybreak    // 青→緑→金(旧: これまで既定)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sunset: return "サンセット"
        case .ocean: return "オーシャン"
        case .twilight: return "トワイライト"
        case .forest: return "フォレスト"
        case .daybreak: return "デイブレイク"
        }
    }

    var colors: [Color] {
        switch self {
        case .sunset:
            return [Color(red: 1.00, green: 0.62, blue: 0.42),
                    Color(red: 0.90, green: 0.45, blue: 0.55),
                    Color(red: 0.65, green: 0.42, blue: 0.85)]
        case .ocean:
            return [Color(red: 0.36, green: 0.76, blue: 0.82),
                    Color(red: 0.32, green: 0.52, blue: 0.92),
                    Color(red: 0.44, green: 0.36, blue: 0.84)]
        case .twilight:
            return [Color(red: 0.50, green: 0.48, blue: 0.92),
                    Color(red: 0.62, green: 0.42, blue: 0.88),
                    Color(red: 0.85, green: 0.48, blue: 0.80)]
        case .forest:
            return [Color(red: 0.30, green: 0.70, blue: 0.46),
                    Color(red: 0.22, green: 0.56, blue: 0.50),
                    Color(red: 0.16, green: 0.42, blue: 0.48)]
        case .daybreak:
            return [Color(red: 0.35, green: 0.62, blue: 0.95),
                    Color(red: 0.42, green: 0.78, blue: 0.62),
                    Color(red: 0.95, green: 0.75, blue: 0.40)]
        }
    }
}

/// 「写真に保存」の下に置く背景グラデ選択ピッカー(○ × 5)。
/// 選択中はリングを強調。タップで即プレビュー&レンダリング画像を更新する。
struct ShareGradientPicker: View {
    @Binding var selectionRaw: String

    var body: some View {
        HStack(spacing: 14) {
            ForEach(ShareCardGradient.allCases) { preset in
                let isSelected = selectionRaw == preset.rawValue
                Button {
                    selectionRaw = preset.rawValue
                } label: {
                    Circle()
                        .fill(
                            LinearGradient(colors: preset.colors,
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle().strokeBorder(.white, lineWidth: isSelected ? 3 : 1.2)
                                .opacity(isSelected ? 1 : 0.55)
                        )
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                        .scaleEffect(isSelected ? 1.12 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("背景 \(preset.label)")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .animation(.easeOut(duration: 0.15), value: selectionRaw)
        .padding(.vertical, 2)
        .accessibilityIdentifier("share-gradient-picker")
    }
}
