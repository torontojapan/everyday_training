import SwiftUI

struct RecordEntryView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RecordEntryViewModel()
    @State private var weightStore: WeightStore?
    @State private var menstrualStore: MenstrualStore?
    @State private var menstrualToday: Bool = false
    /// アコーディオン: 展開中の種目 ID。入力中の 1 種目だけを開き、他は最小化する。
    @State private var expandedExerciseID: UUID?
    private let hapticFeedback = HapticFeedbackController()
    private let cycleSettings = CycleTrackingSettings()
    let onSaved: (WorkoutRecord) -> Void
    /// Deep-link entries (URL scheme / notification tap) pass a custom close
    /// handler so the toolbar button can route back to home. Sheet
    /// presentations leave this nil and fall through to `dismiss()`.
    var onClose: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("種目") {
                    // 各種目がカテゴリを持つ (1 記録に複数カテゴリ可)。入力中の
                    // 1 種目だけを展開し、入力済みの種目は最小化してスッキリ見せる。
                    ForEach(Array($viewModel.drafts.enumerated()), id: \.element.id) { _, $draft in
                        ExerciseInputRow(
                            draft: $draft,
                            suggestions: viewModel.suggestions(for: draft.category),
                            canRemove: viewModel.drafts.count > 1,
                            // 未設定 (nil) のときは先頭種目を展開。onAppear のタイミングに
                            // 依存せず、開いた瞬間から最初の行が編集状態で見える。
                            isExpanded: (expandedExerciseID ?? viewModel.drafts.first?.id) == draft.id,
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedExerciseID = (expandedExerciseID == draft.id) ? nil : draft.id
                                }
                            },
                            onRemove: {
                                let removingId = draft.id
                                viewModel.removeExercise(id: removingId)
                                if expandedExerciseID == removingId {
                                    expandedExerciseID = viewModel.drafts.last?.id
                                }
                            }
                        )
                    }

                    Button {
                        viewModel.addExercise()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedExerciseID = viewModel.drafts.last?.id
                        }
                    } label: {
                        Label("種目を追加", systemImage: "plus.circle.fill")
                            .font(Typography.body)
                    }
                }

                if cycleSettings.isEnabled {
                    Section("体調・周期") {
                        Toggle("今日は生理日", isOn: $menstrualToday)
                            .accessibilityIdentifier("menstrual-toggle")
                    }
                }

                Section("今日の体重 (任意)") {
                    HStack {
                        TextField("体重 (kg)", text: $viewModel.weightInput)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(Palette.textSecondary)
                    }
                    if let latest = weightStore?.latest {
                        Text("前回: \(String(format: "%.1f", latest.weightKilograms)) kg")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    } else {
                        Text("体重を入れるとグラフに反映されます")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                Section("メモ") {
                    TextField("体調や気分など", text: $viewModel.memo, axis: .vertical)
                        .lineLimit(3...5)
                }

                if let message = viewModel.validationMessage {
                    Section {
                        Text(message)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.missed)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        PrimaryButton("保存", systemImage: "checkmark.circle.fill") {
                            if let record = viewModel.save(to: store, weightStore: weightStore) {
                                menstrualStore?.set(menstrualToday, on: store.today)
                                hapticFeedback.success()
                                // 保存後は中間ダイアログを挟まず、達成感のある
                                // 記録完了画面へ直行する。
                                onSaved(record)
                            } else {
                                hapticFeedback.warning()
                            }
                        }
                        .disabled(!viewModel.canSave)
                        .opacity(viewModel.canSave ? 1 : 0.55)

                        // 保存できない時に「なぜ押せないか」をその場で説明。
                        // 以前は disabled = silent でユーザーが詰まりやすかった。
                        if let reason = viewModel.disabledReason {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(Palette.textSecondary)
                                Text(reason)
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .padding(.horizontal, 4)
                            .accessibilityIdentifier("save-disabled-reason")
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("今日の記録")
            .navigationBarTitleDisplayMode(.inline)
            // 時間/回数/セットをプルダウン化してテンキー入力が無くなったため、
            // 旧「完了」キーボードツールバーは撤去。キーボードを使う体重/メモは
            // スワイプ (scrollDismissesKeyboard) で閉じられる。これにより、
            // キーボード非表示時にも下部へ残る白帯+完了ボタンの残留も解消する。
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                viewModel.updateHistoryProvider(store: store)
                if expandedExerciseID == nil {
                    expandedExerciseID = viewModel.drafts.first?.id
                }
                if weightStore == nil {
                    weightStore = WeightStore(context: modelContext)
                }
                if menstrualStore == nil {
                    let mStore = MenstrualStore(context: modelContext)
                    menstrualStore = mStore
                    menstrualToday = mStore.isMarked(store.today)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        if let onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
