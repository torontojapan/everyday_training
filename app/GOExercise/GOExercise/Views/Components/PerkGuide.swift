import SwiftUI

/// 無料で得られる特典・達成イベント1項目。将来の特典追加はこの配列に足すだけ。
struct PerkGuideItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

enum PerkGuide {
    static let items: [PerkGuideItem] = [
        PerkGuideItem(icon: "snowflake", title: "連続記録フリーズ",
                      detail: "無料は月1 / プレミアムは月4。友達紹介で +1(上限5)。招待された人はウェルカム +1。"),
        PerkGuideItem(icon: "star.fill", title: "友達紹介",
                      detail: "1人紹介ごとに⭐とフリーズ。⭐10個で好きな猫が無料で選べるようになります。"),
        PerkGuideItem(icon: "sparkles", title: "達成装飾",
                      detail: "累計日数で背景が進化。30日でシェイカー、100日で王冠が付きます。"),
        PerkGuideItem(icon: "cat.fill", title: "猫種",
                      detail: "無料はオレンジ。プレミアム、または⭐10で全11種から選べます。"),
        PerkGuideItem(icon: "flame.fill", title: "連続記録の節目",
                      detail: "連続記録のマイルストーンでお祝い演出が出ます。"),
    ]
}

/// 設定の「無料特典・達成ガイド」折りたたみセクション(既定は閉)。
struct PerkGuideSection: View {
    var body: some View {
        DisclosureGroup {
            ForEach(PerkGuide.items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.primary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(item.detail)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(.vertical, 2)
            }
        } label: {
            Label("無料でもらえる特典・達成", systemImage: "gift.fill")
                .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityIdentifier("perk-guide-disclosure")
    }
}
