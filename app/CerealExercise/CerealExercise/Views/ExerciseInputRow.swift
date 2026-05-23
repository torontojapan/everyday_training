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

            HStack(spacing: 12) {
                TextField("分", text: $draft.minutes)
                    .keyboardType(.numberPad)
                TextField("秒", text: $draft.seconds)
                    .keyboardType(.numberPad)
                TextField("回数", text: $draft.reps)
                    .keyboardType(.numberPad)
                TextField("セット", text: $draft.sets)
                    .keyboardType(.numberPad)
            }

            TextField("種目メモ", text: $draft.memo, axis: .vertical)
                .lineLimit(1...3)
        }
        .font(Typography.body)
        .padding(.vertical, 6)
    }
}
