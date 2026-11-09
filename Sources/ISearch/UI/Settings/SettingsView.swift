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

                    HStack(spacing: 10) {
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

                        Button("Relaunch i search") {
                            permissionManager.relaunchApp()
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

                    if !permissionManager.hasScreenRecordingPermission {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("⚠️ macOS requires restarting an app after enabling Screen Recording. If you just toggled the switch in System Settings, click **Relaunch i search** above.")
                                .font(.system(size: 11))
                                .foregroundColor(.primary)

                            HStack(spacing: 8) {
                                Text("Not appearing in list?")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)

                                Button("Reveal App in Finder") {
                                    permissionManager.revealAppInFinder()
                                }
                                .controlSize(.small)

                                Text("• Drag app into Settings or click '+'")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        }
                    } else {
                        Text("Screen Recording permission is active. i search can capture selected screen regions.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
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
