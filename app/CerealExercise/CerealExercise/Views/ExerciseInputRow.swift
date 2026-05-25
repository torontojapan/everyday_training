import SwiftUI

struct ExerciseInputRow: View {
    @Binding var draft: RecordEntryViewModel.ExerciseDraft
    let suggestions: [String]
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("種目名", text: $draft.name)
                    .textInputAutocapitalization(.never)

                if canRemove {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("種目を削除")
                }
            }

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                draft.name = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.primaryDeep)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Palette.chipBackground, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(suggestion)を入力")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // Static labels above each numeric field so the meaning doesn't
            // disappear once the user types something (placeholder-only fields
            // lose context after input).
            HStack(spacing: 12) {
                labeledNumberField("時間 (分)", text: $draft.minutes, accessibility: "時間 分単位")
                labeledNumberField("回数", text: $draft.reps, accessibility: "回数")
                labeledNumberField("セット", text: $draft.sets, accessibility: "セット数")
            }

            TextField("種目メモ (例: 体調メモ、回数アップ等)", text: $draft.memo)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Palette.chipBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .font(Typography.body)
        .padding(.vertical, 6)
    }

    private func labeledNumberField(_ label: String, text: Binding<String>, accessibility: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
            TextField("", text: text, prompt: Text("0").foregroundStyle(Palette.textSecondary.opacity(0.5)))
                .keyboardType(.numberPad)
                .accessibilityLabel(accessibility)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
