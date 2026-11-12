import SwiftUI

/// Loading state view with animated spinner, status message, and cancel action.
public struct LoadingStateView: View {
    public let providerName: String
    public let onCancel: () -> Void

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 12)

            VStack(spacing: 4) {
                Text("Analyzing selection...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text("Sending request to \(providerName)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.58, green: 0.65, blue: 0.74))
            }

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .frame(width: 520)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }
}
