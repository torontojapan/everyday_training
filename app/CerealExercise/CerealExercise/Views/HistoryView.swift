import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var viewModel = HistoryViewModel()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if viewModel.groupedByDate.isEmpty {
                    EmptyStateView(message: "まだ記録がないよ。今日から始めよう")
                        .padding(.top, 40)
                } else {
                    ForEach(viewModel.groupedByDate.indices, id: \.self) { index in
                        let date = viewModel.groupedByDate[index].0
                        let records = viewModel.groupedByDate[index].1
                        VStack(alignment: .leading, spacing: 10) {
                            Text(dateFormatter.string(from: date))
                                .font(Typography.sectionTitle)
                                .foregroundStyle(Palette.textPrimary)

                            ForEach(records) { record in
                                HistoryRowView(record: record)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("履歴")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.fetchRecords()
            viewModel.refresh(records: store.records)
        }
    }
}
