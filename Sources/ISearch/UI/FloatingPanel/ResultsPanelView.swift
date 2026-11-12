import SwiftUI
import AppKit

/// Unified container view for the floating results panel with reactive state transitions and error recovery.
@MainActor
public struct ResultsPanelView: View {
    public enum ErrorType: Equatable {
        case missingPermission
        case missingCredentials
        case generic
    }

    public enum PanelState {
        case review
        case loading
        case response(text: String)
        case error(message: String, type: ErrorType)
    }

    @ObservedObject public var appState: AppState = AppState.shared
    public let thumbnail: NSImage
    public let providerName: String
    public let onSubmitPrompt: (String) -> Void
    public let onCancelRequest: () -> Void
    public let onNewSelection: () -> Void
    public let onOpenSettings: () -> Void
    public var onOpenSystemSettings: (() -> Void)? = nil
    public var onRevealInFinder: (() -> Void)? = nil
    public let onSwitchToMock: () -> Void
    public let onClose: () -> Void

    @MainActor
    public init(
        appState: AppState = AppState.shared,
        thumbnail: NSImage,
        providerName: String,
        onSubmitPrompt: @escaping (String) -> Void,
        onCancelRequest: @escaping () -> Void,
        onNewSelection: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenSystemSettings: (() -> Void)? = nil,
        onRevealInFinder: (() -> Void)? = nil,
        onSwitchToMock: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.appState = appState
        self.thumbnail = thumbnail
        self.providerName = providerName
        self.onSubmitPrompt = onSubmitPrompt
        self.onCancelRequest = onCancelRequest
        self.onNewSelection = onNewSelection
        self.onOpenSettings = onOpenSettings
        self.onOpenSystemSettings = onOpenSystemSettings
        self.onRevealInFinder = onRevealInFinder
        self.onSwitchToMock = onSwitchToMock
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            switch appState.panelState {
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
            case .error(let message, let type):
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 16))
                        Text(type == .missingPermission ? "Permission Required" : "Analysis Notice")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: onClose) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 28, height: 28)
                                Circle()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.75))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.65, green: 0.72, blue: 0.82))
                        .lineSpacing(3)

                    HStack(spacing: 10) {
                        switch type {
                        case .missingPermission:
                            Button("Relaunch App") {
                                PermissionManager.shared.relaunchApp()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Open Settings") {
                                onOpenSystemSettings?()
                            }
                            .buttonStyle(.bordered)

                            Button("Reveal in Finder") {
                                onRevealInFinder?()
                            }
                            .buttonStyle(.bordered)

                        case .missingCredentials:
                            Button("Try Demo Mode Now") {
                                onSwitchToMock()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Open Settings") {
                                onOpenSettings()
                            }
                            .buttonStyle(.bordered)

                        case .generic:
                            Button("Try Again") {
                                appState.panelState = .review
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
                .padding(20)
                .frame(width: 520)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.055, green: 0.075, blue: 0.115).opacity(0.94),
                                Color(red: 0.075, green: 0.105, blue: 0.155).opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.09), Color.clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 280
                        )
                    )
            }
            .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
            .shadow(color: Color(red: 0.10, green: 0.25, blue: 0.50).opacity(0.12), radius: 30, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
