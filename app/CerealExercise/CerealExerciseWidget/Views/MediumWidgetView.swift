import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 6) {
                WidgetCatView(rawState: snapshot.catState)
                Text(catState.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.54, green: 0.47, blue: 0.39))
            }
            .frame(width: 76)

            VStack(alignment: .leading, spacing: 10) {
                Text("今週 \(snapshot.weeklyAchieved)/\(snapshot.weeklyTotal) 達成")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.30, green: 0.25, blue: 0.20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(snapshot.message)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.30, green: 0.25, blue: 0.20))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(remainingText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(red: 0.54, green: 0.47, blue: 0.39))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var catState: CatState {
        CatState(rawValue: snapshot.catState) ?? .waitingMorning
    }

    private var remainingText: String {
        if snapshot.todayAchieved {
            return "今日は達成済み"
        }
        if snapshot.isRestDay {
            return "今日は整える日"
        }
        return "23:59まであと\(snapshot.nightDeadlineHoursLeft)時間"
    }
}
