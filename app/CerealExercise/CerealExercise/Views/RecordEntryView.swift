import SwiftUI

struct RecordEntryView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RecordEntryViewModel()
    @State private var weightStore: WeightStore?
    @State private var menstrualStore: MenstrualStore?
    @State private var menstrualToday: Bool = false
    @State private var pendingSavedRecord: WorkoutRecord?
    @State private var isShowingSaveOptions = false
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
                Section("カテゴリ") {
                    // 横スクロール chip → 2 行グリッド。全 6 カテゴリが
                    // 一目で見え、選択中は強調 + checkmark で「単一選択」が
                    // 視覚的に伝わる。
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(WorkoutCategory.allCases) { category in
                            CategoryChip(category: category, isSelected: viewModel.selectedCategory == category) {
                                viewModel.selectedCategory = category
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }

                Section("種目") {
                    ForEach(Array($viewModel.drafts.enumerated()), id: \.element.id) { index, $draft in
                        VStack(alignment: .leading, spacing: 4) {
                            // 種目 N ラベル: 複数追加時に「どれを編集中か」
                            // 視覚的に明示。1 種目だけならラベルは省略。
                            if viewModel.drafts.count > 1 {
                                Text("種目 \(index + 1)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Palette.textSecondary)
                                    .textCase(nil)
                            }
                            ExerciseInputRow(
                                draft: $draft,
                                suggestions: viewModel.suggestions(for: viewModel.selectedCategory),
                                canRemove: viewModel.drafts.count > 1,
                                onRemove: {
                                    viewModel.removeExercise(id: draft.id)
                                }
                            )
                        }
                    }

                    if viewModel.suggestions(for: viewModel.selectedCategory).isEmpty {
                        Text("履歴がたまると、ここによく使う種目が出ます")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }

                    Button {
                        viewModel.addExercise()
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
                                pendingSavedRecord = record
                                isShowingSaveOptions = true
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
            // iOS の number/decimal pad は標準で「完了」ボタンが出ないため、
            // 全 numeric TextField の上に共通ツールバーを差し込む。これがない
            // と入力後にキーボードが画面下に居座り、保存ボタンが押せない。
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("keyboard-done")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .confirmationDialog("保存しました", isPresented: $isShowingSaveOptions, titleVisibility: .visible, presenting: pendingSavedRecord) { record in
                Button("続けて記録") {
                    viewModel.resetAfterSave()
                    pendingSavedRecord = nil
                }
                Button("完了画面を開く") {
                    onSaved(record)
                    pendingSavedRecord = nil
                }
                Button("キャンセル", role: .cancel) {
                    pendingSavedRecord = nil
                }
            } message: { _ in
                Text("次の操作を選んでください")
            }
            .onAppear {
                viewModel.updateHistoryProvider(store: store)
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
