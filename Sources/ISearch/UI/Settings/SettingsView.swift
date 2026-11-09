import SwiftUI

/// Comprehensive Preferences and Settings window for i search.
public struct SettingsView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared
    public let onTriggerSelection: () -> Void

    public init(onTriggerSelection: @escaping () -> Void) {
        self.onTriggerSelection = onTriggerSelection
    }

    public var body: some View {
        TabView {
            // General Tab
            VStack(alignment: .leading, spacing: 20) {
                ShortcutSettingsView(onTestShortcut: onTriggerSelection)

                Divider()

                // Screen Capture Permission Card
                VStack(alignment: .leading, spacing: 10) {
                    Text("Screen Recording Permission")
                        .font(.system(size: 13, weight: .semibold))

                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(permissionManager.hasScreenRecordingPermission ? Color.green : Color.orange)
                                .frame(width: 10, height: 10)

                            Text(permissionManager.hasScreenRecordingPermission ? "Permission Granted" : "Permission Missing")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(permissionManager.hasScreenRecordingPermission ? .green : .orange)
                        }

                        Button("Check Status") {
                            permissionManager.checkPermission()
                        }
                        .controlSize(.small)

                        Spacer()

                        if !permissionManager.hasScreenRecordingPermission {
                            Button("Open System Settings") {
                                permissionManager.openSystemSettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }

                    Text("macOS requires Screen Recording permission so i search can capture your selected area.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(20)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            // AI Model Tab
            ScrollView {
                AISettingsView()
                    .padding(20)
            }
            .tabItem {
                Label("AI Provider", systemImage: "sparkles")
            }

            // Privacy Tab
            VStack(alignment: .leading, spacing: 16) {
                PrivacyInfoView()
                Spacer()
            }
            .padding(20)
            .tabItem {
                Label("Privacy", systemImage: "lock.shield")
            }
        }
        .frame(width: 520, height: 420)
    }
}
