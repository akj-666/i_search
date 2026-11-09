import SwiftUI
import AppKit

/// Unified container view for the floating results panel with state transitions and error recovery.
public struct ResultsPanelView: View {
    public enum PanelState {
        case review
        case loading
        case response(text: String)
        case error(message: String, isMissingCredentials: Bool)
    }

    public let thumbnail: NSImage
    public let providerName: String
    @Binding public var state: PanelState
    public let onSubmitPrompt: (String) -> Void
    public let onCancelRequest: () -> Void
    public let onNewSelection: () -> Void
    public let onOpenSettings: () -> Void
    public let onSwitchToMock: () -> Void
    public let onClose: () -> Void

    public var body: some View {
        ZStack {
            switch state {
            case .review:
                ReviewCardView(
                    thumbnail: thumbnail,
                    providerName: providerName,
                    onSubmit: onSubmitPrompt,
                    onNewSelection: onNewSelection,
                    onCancel: onClose
                )
            case .loading:
                LoadingStateView(
                    providerName: providerName,
                    onCancel: onCancelRequest
                )
            case .response(let text):
                ResponseCardView(
                    responseText: text,
                    providerName: providerName,
                    onFollowUp: onSubmitPrompt,
                    onNewSelection: onNewSelection,
                    onClose: onClose
                )
            case .error(let message, let isMissingCredentials):
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 16))
                        Text("Analysis Error")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)

                    HStack(spacing: 10) {
                        if isMissingCredentials {
                            Button("Open Settings") {
                                onOpenSettings()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Try Demo Mode") {
                                onSwitchToMock()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Try Again") {
                                state = .review
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Spacer()

                        Button("New Selection") {
                            onNewSelection()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .frame(width: 440)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}
