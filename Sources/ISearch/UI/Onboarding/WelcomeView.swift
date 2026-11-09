import SwiftUI

/// Welcome and onboarding view shown on first launch.
public struct WelcomeView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var shortcutManager = GlobalShortcutManager.shared
    public let onTestShortcut: () -> Void
    public let onComplete: () -> Void

    public init(onTestShortcut: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.onTestShortcut = onTestShortcut
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Hero Icon and Title
            VStack(spacing: 8) {
                Image(systemName: "viewfinder.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                Text("Welcome to i search")
                    .font(.system(size: 20, weight: .bold))

                Text("Circle to search, for your Mac.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 12)

            // Step Cards
            VStack(alignment: .leading, spacing: 14) {
                stepRow(
                    icon: "command",
                    iconColor: .blue,
                    title: "1. Press your global shortcut",
                    description: "Press \(shortcutManager.currentCombo.displayString) anytime to dim your screen and activate the crosshair selector."
                )

                stepRow(
                    icon: "selection.pin.in.out",
                    iconColor: .purple,
                    title: "2. Drag to select any visible content",
                    description: "Drag around any text, image, code, or interface element—even inside another application."
                )

                stepRow(
                    icon: "sparkles",
                    iconColor: .orange,
                    title: "3. Get instant AI insights",
                    description: "Ask questions, transcribe text, or explain complex diagrams in a compact floating panel."
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )

            // Screen Recording Permission Box
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(permissionManager.hasScreenRecordingPermission ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)

                    Text(permissionManager.hasScreenRecordingPermission ? "Screen Recording Permission: Granted" : "Screen Recording Permission Required")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(permissionManager.hasScreenRecordingPermission ? .green : .primary)

                    Spacer()

                    if !permissionManager.hasScreenRecordingPermission {
                        Button("Grant in Settings") {
                            permissionManager.openSystemSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("Check") {
                            permissionManager.checkPermission()
                        }
                        .controlSize(.small)
                    }
                }

                Text("macOS requires this permission to capture only the specific region you choose to select. Nothing is recorded in the background.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(permissionManager.hasScreenRecordingPermission ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
            )

            // Footer Actions
            HStack(spacing: 12) {
                Button("Test Selection Now") {
                    onTestShortcut()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Get Started") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            permissionManager.checkPermission()
        }
    }

    private func stepRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
                .background(iconColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
    }
}
