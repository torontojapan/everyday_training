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
        PerkGuideItem(icon: "snowflake", title: "保険チケット",
                      detail: "無料は月1 / プレミアムは月4。友達紹介で +1(上限5)。招待された人はウェルカム +1。"),
        PerkGuideItem(icon: "star.fill", title: "友達紹介",
                      detail: "1人紹介ごとに⭐と保険チケット。⭐10個で好きなキャラが無料で選べるようになります。"),
        PerkGuideItem(icon: "rosette", title: "称号 & 背景の進化",
                      detail: "連続記録を続けると相棒の称号が上がり(全11段)、背景も豪華に進化します。下の「称号一覧」で目標を確認できます。"),
        PerkGuideItem(icon: "pawprint.fill", title: "キャラの種類",
                      detail: "無料は最初に選んだ相棒のまま。プレミアム、または⭐10で猫12種・犬13種から自由に選べます。"),
        PerkGuideItem(icon: "pawprint.fill", title: "連続記録の節目",
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

/// 設定の「称号一覧」表示。連続記録で進化する全11段の称号を一覧し、
/// 現在地と次の目標を示して「あと少しで上の称号」という前進動機を作る。
/// アニメーションは持たせず(静的メタルドット)、開いても軽い。
struct CatRankGuideView: View {
    let currentStreak: Int

    private var currentRank: Int { CatRank(currentStreak: currentStreak).rank }
    /// 称号の種別(犬なら「○○犬」)。設定で選んでいるキャラに追従。
    private var species: PetSpecies { UserCatPreferences.shared.myPet.species }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            targetHint
                .padding(.bottom, 10)

            ForEach(Array(CatRank.thresholds.enumerated()), id: \.offset) { idx, threshold in
                let rank = idx + 1
                let entry = CatRank(currentStreak: threshold)
                let isCurrent = rank == currentRank
                let achieved = currentStreak >= threshold

                HStack(spacing: 10) {
                    metalDot(entry.metalKind ?? .bronze)
                    Text(entry.title(species: species) ?? "")
                        .font(.system(.subheadline, design: .rounded, weight: isCurrent ? .heavy : .semibold))
                        .foregroundStyle(achieved || isCurrent ? Palette.textPrimary : Palette.textSecondary)
                    if isCurrent {
                        Text("いま")
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Palette.primary))
                    }
                    Spacer(minLength: 8)
                    Text("\(threshold)日")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(achieved ? Palette.primaryDeep : Palette.textSecondary)
                }
                .padding(.vertical, 5)
                .opacity(achieved || isCurrent ? 1 : 0.8)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
    }

    /// 次の目標(あとN日)を示すヒント。最高位なら賞賛。
    @ViewBuilder private var targetHint: some View {
        if currentRank >= CatRank.thresholds.count {
            let topTitle = CatRank(currentStreak: CatRank.thresholds.last ?? 500).title(species: species) ?? ""
            Label("最高位「\(topTitle)」を達成！", systemImage: "crown.fill")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.primaryDeep)
        } else {
            let nextThreshold = CatRank.thresholds[currentRank]
            let nextTitle = CatRank(currentStreak: nextThreshold).title(species: UserCatPreferences.shared.myPet.species) ?? ""
            let remaining = max(0, nextThreshold - currentStreak)
            Text("連続記録を続けると称号が進化。次は「\(nextTitle)」まで あと\(remaining)日！")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.primaryDeep)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metalDot(_ kind: MetalKind) -> some View {
        Circle()
            .fill(
                MetalStyle.isRainbow(kind)
                    ? AnyShapeStyle(AngularGradient(colors: MetalStyle.rainbowColors, center: .center))
                    : AnyShapeStyle(MetalStyle.fillGradient(kind))
            )
            .frame(width: 15, height: 15)
            .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
    }
}
