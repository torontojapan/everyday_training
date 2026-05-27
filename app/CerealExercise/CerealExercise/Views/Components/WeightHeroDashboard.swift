import SwiftUI
import UIKit

/// 体重タブのヒーローダッシュボード。
/// 旧 `summarySection` + `targetSection` を統合し、最も見たい情報
/// (現在の体重 / 目標までの距離) を **1 枚** にまとめる。
///
/// レイアウト:
/// - 上段ヘッダ: 「最新の体重 · 日付 · 目標を変更」
/// - 中段: 巨大な現在体重 (kg) (左) + 達成リング + 選択中の猫キャラ (右)
/// - 下段 KPI チップ: `あと N kg` / `今週 ±N kg` (横スクロール対応)
/// - 最下段: 開始 → 目標 のミニラベル
///
/// 目標未設定や記録 0 件のときは段階的に degrade する。
struct WeightHeroDashboard: View {
    let latest: WeightEntry?
    let startKg: Double?
    let targetKg: Double?
    let progress: Double?            // 0..1, nil なら未設定
    let isLossGoal: Bool?            // true=減量, false=増量, nil=未設定/差なし
    let weeklyChange: Double?        // 今週の変化 (kg)
    let onEditTarget: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 猫 avatar の asset 名を init 時に 1 回だけ解決してキャッシュ。
    /// `UIImage(named:)` を毎レンダー呼ばないため (Codex round1 priority 3)。
    private let cachedCatAssetName: String?

    init(latest: WeightEntry?,
         startKg: Double?,
         targetKg: Double?,
         progress: Double?,
         isLossGoal: Bool?,
         weeklyChange: Double?,
         onEditTarget: @escaping () -> Void) {
        self.latest = latest
        self.startKg = startKg
        self.targetKg = targetKg
        self.progress = progress
        self.isLossGoal = isLossGoal
        self.weeklyChange = weeklyChange
        self.onEditTarget = onEditTarget
        // breed × state を 1 回解決し、欠落していれば fallback、それでも無ければ nil。
        // テスト/プレビューで Assets が無い環境でも crash しないよう堅牢に。
        let breed = UserCatPreferences.shared.myCat
        let primary = breed.assetName(for: .waitingMorning)
        if UIImage(named: primary) != nil {
            self.cachedCatAssetName = primary
        } else {
            let fallback = CatBreed.fallbackAssetName(for: .waitingMorning)
            self.cachedCatAssetName = UIImage(named: fallback) != nil ? fallback : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 上段ヘッダ: 「最新の体重」+ 日付 / 右に「変更」(目標があれば)
            HStack(alignment: .firstTextBaseline) {
                Text("最新の体重")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                if let date = latest?.date {
                    Text("·")
                        .foregroundStyle(Palette.textSecondary.opacity(0.6))
                    Text(dateLabel(date))
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Button(action: onEditTarget) {
                    Label(targetKg == nil ? "目標を設定" : "目標を変更",
                          systemImage: "target")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.primaryDeep)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hero-edit-target")
            }

            // 中段: 巨大体重数字 (左) + リング+猫 (右)、余白多めでバランス
            HStack(alignment: .center, spacing: 20) {
                primaryWeight
                Spacer(minLength: 8)
                ringWithCat
            }

            // KPI チップ (あと N kg / 今週 ±N kg) - 横スクロール対応
            if latest != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    kpiChips
                }
            }

            // 開始 → 目標 のミニラベル (薄い divider 下に)
            if let startKg, let targetKg {
                Divider().opacity(0.5)
                HStack(spacing: 6) {
                    Text("開始")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                    Text(String(format: "%.1f", startKg))
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Palette.textSecondary)
                    Text("目標")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                    Text(String(format: "%.1f kg", targetKg))
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.primaryDeep)
                        .monospacedDigit()
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Palette.surface, Palette.primary.opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Palette.primary.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Palette.primary.opacity(0.08), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weight-hero-dashboard")
    }

    @ViewBuilder
    private var primaryWeight: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let latest {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", latest.weightKilograms))
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.primary)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("kg")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
            } else {
                Text("未記録")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Text("まずは 1 件記録してみよう")
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var ringWithCat: some View {
        let ringSize: CGFloat = 108
        let lineWidth: CGFloat = 9
        ZStack {
            Circle()
                .stroke(Palette.primary.opacity(0.18), lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)
            if let progress {
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                    .stroke(Palette.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: ringSize, height: ringSize)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: progress)
            }
            // 中央に猫 (init でキャッシュ済み asset 名)
            ZStack {
                Circle()
                    .fill(Palette.surface)
                    .frame(width: ringSize - 24, height: ringSize - 24)
                if let name = cachedCatAssetName {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: ringSize - 26, height: ringSize - 26)
                        .clipShape(Circle())
                } else {
                    Text("🐱").font(.system(size: 42))
                }
            }
            // 進捗バッジ (リング右下、視認性高めに primaryDeep 背景)
            if let progress {
                Text("\(Int((max(0, min(1, progress)) * 100).rounded()))%")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Palette.primaryDeep, in: Capsule())
                    .overlay(Capsule().strokeBorder(Palette.surface, lineWidth: 2))
                    .offset(x: 30, y: 38)
            }
        }
        .frame(width: ringSize + 12, height: ringSize + 12)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var kpiChips: some View {
        HStack(spacing: 8) {
            // 「あと」KPI は **isLossGoal が nil の場合でも** 動作させる
            // (Codex round1 priority 1: start == target / start 未設定でも
            //  latest と target があれば差分 = abs(latest - target) で出せる)。
            if let targetKg, let latestKg = latest?.weightKilograms {
                let signedDelta = latestKg - targetKg  // 正なら現在が target より重い
                let direction = isLossGoal ?? (signedDelta > 0)  // fallback: 差分の符号で推定
                let remaining = direction
                    ? max(0, signedDelta)        // 減量: 現在 - 目標
                    : max(0, -signedDelta)       // 増量: 目標 - 現在
                if remaining < 0.05 {
                    kpiChip(emoji: "✓", title: "圏内", value: "達成", tone: .success)
                } else {
                    kpiChip(emoji: "📏", title: "あと",
                            value: String(format: "%.1f kg", remaining), tone: .primary)
                }
            }

            if let weeklyChange {
                let sign = weeklyChange == 0 ? "" : (weeklyChange > 0 ? "+" : "")
                kpiChip(
                    emoji: weeklyChange <= 0 ? "↘" : "↗",
                    title: "今週",
                    value: "\(sign)\(String(format: "%.1f", weeklyChange))kg",
                    tone: weeklyChange <= 0 ? .success : .warning
                )
            }
            Spacer()
        }
    }

    private enum ChipTone { case primary, success, warning, secondary }
    private func chipColor(_ tone: ChipTone) -> Color {
        switch tone {
        case .primary:   return Palette.primaryDeep
        case .success:   return Palette.success
        case .warning:   return Palette.missed
        case .secondary: return Palette.textSecondary
        }
    }

    private func kpiChip(emoji: String, title: String, value: String, tone: ChipTone) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.caption2)
            Text(title).font(.caption2).foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(chipColor(tone))
                .monospacedDigit()
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(chipColor(tone).opacity(0.12), in: Capsule())
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        // 時刻が 00:00 以外なら時刻も出す (insert 化後の time-of-day を活用)
        let comp = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        if comp.hour == 0 && comp.minute == 0 && comp.second == 0 {
            f.dateFormat = "yyyy/M/d"
        } else {
            f.dateFormat = "yyyy/M/d HH:mm"
        }
        return f.string(from: date)
    }
}
