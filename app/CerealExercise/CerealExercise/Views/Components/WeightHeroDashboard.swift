import SwiftUI
import UIKit

/// 体重タブのヒーローダッシュボード。
/// 旧 `summarySection` + `targetSection` を統合し、最も見たい情報
/// (現在の体重 / 目標までの距離 / 達成見込み) を **1 枚** にまとめる。
///
/// レイアウト (左から右へ):
/// - 中央: 巨大な現在体重 (kg) + 直下に小さく日付
/// - 右側: 達成リング (進捗 0..1) + 選択中の猫キャラ
/// - 下段 KPI チップ: `あと N kg` / `今週 ±N kg` / `達成見込み N 日`
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
    let forecastDays: Int?           // 達成までの予測日数, 0=圏内
    let onEditTarget: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 上段: 体重大 + リング + 猫
            HStack(alignment: .center, spacing: 16) {
                primaryWeight
                Spacer()
                ringWithCat
            }

            // KPI チップ (目標 / 今週 / 達成見込み)
            if latest != nil {
                kpiChips
            }

            // 開始 → 目標 のサブストリップ
            if let startKg, let targetKg {
                Divider()
                HStack(spacing: 12) {
                    miniLabel(emoji: "🚩", title: "開始", value: String(format: "%.1f kg", startKg))
                    miniLabel(emoji: "🎯", title: "目標", value: String(format: "%.1f kg", targetKg))
                    Spacer()
                    Button(action: onEditTarget) {
                        Label("変更", systemImage: "pencil")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.primaryDeep)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hero-edit-target")
                }
            } else {
                Button(action: onEditTarget) {
                    Label(targetKg == nil ? "目標体重を設定する" : "目標を変更",
                          systemImage: "target")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.primaryDeep)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hero-edit-target")
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Palette.surface, Palette.primary.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.primary.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weight-hero-dashboard")
    }

    @ViewBuilder
    private var primaryWeight: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("最新の体重")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            if let latest {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", latest.weightKilograms))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.primary)
                        .monospacedDigit()
                    Text("kg")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textSecondary)
                }
                Text(dateLabel(latest.date))
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                Text("未記録")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Text("まずは 1 件記録してみよう")
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var ringWithCat: some View {
        ZStack {
            // ベースリング
            Circle()
                .stroke(Palette.primary.opacity(0.18), lineWidth: 8)
                .frame(width: 92, height: 92)
            // 進捗
            if let progress {
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                    .stroke(Palette.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 92, height: 92)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: progress)
            }
            // 中央に猫
            ZStack {
                Circle()
                    .fill(Palette.surface)
                    .frame(width: 72, height: 72)
                if let img = catAssetImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                } else {
                    Text("🐱").font(.system(size: 36))
                }
            }
            // 進捗バッジ (リングの右下)
            if let progress {
                Text("\(Int((max(0, min(1, progress)) * 100).rounded()))%")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Palette.primaryDeep)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
                    .offset(x: 30, y: 32)
            }
        }
        .frame(width: 100, height: 100)
        .accessibilityHidden(true)
    }

    /// 選択中の猫キャラを CelebrationState の waitingMorning ポーズで取得。
    /// asset 欠落時は nil → emoji へフォールバック。
    private var catAssetImage: UIImage? {
        let breed = UserCatPreferences.shared.myCat
        let name = breed.assetName(for: .waitingMorning)
        if let img = UIImage(named: name) { return img }
        return UIImage(named: CatBreed.fallbackAssetName(for: .waitingMorning))
    }

    @ViewBuilder
    private var kpiChips: some View {
        HStack(spacing: 8) {
            if let isLossGoal, let targetKg, let latestKg = latest?.weightKilograms {
                let remaining = isLossGoal ? max(0, latestKg - targetKg) : max(0, targetKg - latestKg)
                if abs(remaining) < 0.05 {
                    kpiChip(emoji: "✓", title: "圏内", value: "達成", tone: .success)
                } else {
                    kpiChip(emoji: "📏", title: "あと",
                            value: String(format: "%.1f kg", remaining), tone: .primary)
                }
            } else if targetKg != nil {
                kpiChip(emoji: "📏", title: "あと", value: "—", tone: .secondary)
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

            if let forecastDays {
                let label = forecastDays == 0 ? "圏内" : "約\(forecastDays)日"
                kpiChip(emoji: "📅", title: "達成見込", value: label, tone: .primary)
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

    private func miniLabel(emoji: String, title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.caption2)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
        }
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
