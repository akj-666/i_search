import SwiftUI

/// Reusable chip component for quick prompt selection.
public struct ActionChip: View {
    public let title: String
    public let iconName: String
    public let isSelected: Bool
    public let action: () -> Void

    public init(title: String, iconName: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.iconName = iconName
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}
