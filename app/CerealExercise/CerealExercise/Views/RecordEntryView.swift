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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(WorkoutCategory.allCases) { category in
                                CategoryChip(category: category, isSelected: viewModel.selectedCategory == category) {
                                    viewModel.selectedCategory = category
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                }

                Section("種目") {
                    ForEach($viewModel.drafts) { $draft in
                        ExerciseInputRow(
                            draft: $draft,
                            suggestions: viewModel.suggestions(for: viewModel.selectedCategory),
                            canRemove: viewModel.drafts.count > 1,
                            onRemove: {
                                viewModel.removeExercise(id: draft.id)
                            }
                        )
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
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("今日の記録")
            .navigationBarTitleDisplayMode(.inline)
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
