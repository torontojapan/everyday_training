import WidgetKit
import SwiftUI

@main
struct GOExerciseWidgetBundle: WidgetBundle {
    var body: some Widget {
        GOExerciseWidget()
        CatLiveActivity()
    }
}

struct GOExerciseWidget: Widget {
    let kind = "GOExerciseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            GOExerciseWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    // 目に留まりやすい温かみのあるグラデーション + やわらかい光彩。
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.95, blue: 0.86),
                                Color(red: 1.00, green: 0.89, blue: 0.78),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        RadialGradient(
                            colors: [Color(red: 1.00, green: 0.78, blue: 0.55).opacity(0.55), .clear],
                            center: .topTrailing, startRadius: 4, endRadius: 180
                        )
                    }
                }
                .widgetURL(URL(string: "goexercise://home"))
        }
        .configurationDisplayName("GO エクササイズ")
        .description("今日の残り時間、週間達成率、猫メッセージを表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct GOExerciseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(snapshot: entry.snapshot)
        default:
            MediumWidgetView(snapshot: entry.snapshot)
        }
    }
}
