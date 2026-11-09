import SwiftUI

/// View detailing image privacy and data handling guarantees.
public struct PrivacyInfoView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
                Text("Privacy & Data Handling")
                    .font(.system(size: 13, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                        .padding(.top, 2)
                    Text("**Only selected regions are captured**: i search never records your full screen or captures anything in the background.")
                        .font(.system(size: 11))
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                        .padding(.top, 2)
                    Text("**Explicit submission only**: Images are transmitted to the AI provider only after you review the preview and click Submit.")
                        .font(.system(size: 11))
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                        .padding(.top, 2)
                    Text("**Strictly in-memory**: Captured images are processed in RAM and discarded immediately when the results panel is dismissed. No screenshots are saved to disk.")
                        .font(.system(size: 11))
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                        .padding(.top, 2)
                    Text("**Secure Keychain storage**: API keys are encrypted in the macOS Keychain and never stored in plain text or logged.")
                        .font(.system(size: 11))
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}
