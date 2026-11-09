import SwiftUI
import Carbon

/// Settings section for viewing and configuring the global keyboard shortcut.
public struct ShortcutSettingsView: View {
    @ObservedObject private var shortcutManager = GlobalShortcutManager.shared
    public let onTestShortcut: () -> Void

    public init(onTestShortcut: @escaping () -> Void) {
        self.onTestShortcut = onTestShortcut
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Global Keyboard Shortcut")
                .font(.system(size: 13, weight: .semibold))

            Text("Press this shortcut anywhere across macOS to dim the screen and select an area for AI analysis.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Current Shortcut Display
            HStack(spacing: 12) {
                Text(shortcutManager.currentCombo.displayString)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )

                Button("Reset to ⌘⇧Space") {
                    shortcutManager.resetToDefault()
                }
                .disabled(shortcutManager.currentCombo == .default)

                Spacer()

                Button("Test Overlay Now") {
                    onTestShortcut()
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // Preset shortcuts
            VStack(alignment: .leading, spacing: 6) {
                Text("Popular Presets")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    presetButton("⌘⇧Space (Default)", combo: .default)
                    presetButton("⌥Space", combo: KeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(optionKey)))
                    presetButton("⌃⌥Space", combo: KeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(controlKey | optionKey)))
                    presetButton("⌘⇧S", combo: KeyCombo(keyCode: UInt32(kVK_ANSI_S), carbonModifiers: UInt32(cmdKey | shiftKey)))
                }
            }
        }
    }

    private func presetButton(_ title: String, combo: KeyCombo) -> some View {
        let isSelected = shortcutManager.currentCombo == combo
        return Button(action: {
            shortcutManager.register(combo: combo)
        }) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
