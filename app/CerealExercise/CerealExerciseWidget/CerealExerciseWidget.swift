import WidgetKit
import SwiftUI

@main
struct CerealExerciseWidgetBundle: WidgetBundle {
    var body: some Widget {
        CerealExerciseWidget()
    }
}

struct CerealExerciseWidget: Widget {
    let kind = "CerealExerciseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            CerealExerciseWidgetView(entry: entry)
                .containerBackground(Color(red: 1.00, green: 0.97, blue: 0.93), for: .widget)
                .widgetURL(URL(string: "cerealexercise://record"))
        }
        .configurationDisplayName("GOエクササイズ")
        .description("今日の残り時間、週間達成率、猫メッセージを表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct CerealExerciseWidgetView: View {
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
