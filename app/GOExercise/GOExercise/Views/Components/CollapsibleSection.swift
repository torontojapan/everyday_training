import SwiftUI

/// 折りたたみ可能なセクションカード。
/// 体重タブで「主要 KPI 以外」を最小化して縦長スクロールを抑えるために使う。
/// 最小化時はタイトル + 任意の要約 (例: 「-0.6kg / 平均 65.3kg」) を 1 行で表示し、
/// タップ or アイコンで展開。展開状態はキー単位で UserDefaults に永続化されるので
/// アプリ再起動後もユーザーの好みが残る。
///
/// 使い方:
/// ```swift
/// CollapsibleSection(
///     persistenceKey: "weight.report",
///     title: "レポート",
///     subtitle: "今週 -0.6kg / 今月 -3.1kg",
///     icon: "chart.bar.fill"
/// ) {
///     statsReportSection(store: store)
/// }
/// ```
struct CollapsibleSection<Content: View>: View {
    let persistenceKey: String
    let title: String
    /// 折りたたみ中の補足文字列。要約や key indicator を 1 行で。
    let subtitle: String?
    let icon: String?
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 折りたたみ状態の UserDefaults キー前缀。
    private static var prefix: String { "collapsible.expanded." }

    init(persistenceKey: String,
         title: String,
         subtitle: String? = nil,
         icon: String? = nil,
         defaultExpanded: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.persistenceKey = persistenceKey
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content
        let key = Self.prefix + persistenceKey
        let stored = UserDefaults.standard.object(forKey: key) as? Bool
        _isExpanded = State(initialValue: stored ?? defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isExpanded {
                // ヘッダの下に向かって自然に伸びるよう、上端スライドではなく
                // フェードのみ (高さアニメは外側の .animation が担当)。
                content()
                    .transition(.opacity)
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
    }

    private var header: some View {
        Button {
            isExpanded.toggle()
            UserDefaults.standard.set(isExpanded, forKey: Self.prefix + persistenceKey)
        } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Palette.primaryDeep)
                        .frame(width: 20)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    // 折りたたみ中だけ subtitle を出す。展開時は本文と二重になるので隠す。
                    if !isExpanded, let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Palette.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title + (subtitle.map { " " + $0 } ?? ""))
        .accessibilityHint(isExpanded ? "ダブルタップで閉じる" : "ダブルタップで開く")
        .accessibilityAddTraits(isExpanded ? [.isSelected] : [])
    }
}
