import SwiftUI

struct CategoryChip: View {
    let category: WorkoutCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(category.displayName, systemImage: category.symbolName)
                .font(Typography.caption)
                .foregroundStyle(isSelected ? .white : Palette.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isSelected ? Palette.primary : Palette.secondary.opacity(0.7), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
