import SwiftUI

/// Loading state view with animated spinner, status message, and cancel action.
public struct LoadingStateView: View {
    public let providerName: String
    public let onCancel: () -> Void

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("Analyzing selection...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Sending request to \(providerName)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }
}
