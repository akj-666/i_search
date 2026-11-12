import SwiftUI
import AppKit

@MainActor
public final class ResponseCardViewModel: ObservableObject {
    @Published public var followUpText: String = ""
    @Published public var isCopied: Bool = false

    public init() {}
}

/// Card view displaying the AI response with markdown formatting, copying, follow-up queries, and reselection.
public struct ResponseCardView: View {
    public let responseText: String
    public let providerName: String
    public let onFollowUp: (String) -> Void
    public let onNewSelection: () -> Void
    public let onClose: () -> Void

    @StateObject private var vm = ResponseCardViewModel()
    @FocusState private var isFollowUpFocused: Bool

    public init(
        responseText: String,
        providerName: String,
        onFollowUp: @escaping (String) -> Void,
        onNewSelection: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.responseText = responseText
        self.providerName = providerName
        self.onFollowUp = onFollowUp
        self.onNewSelection = onNewSelection
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    AppIconView(size: 16)

                    Text("i search")
                        .font(.system(size: 13, weight: .bold))

                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))

                    Text(providerName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    // Copy button
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: vm.isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(vm.isCopied ? "Copied" : "Copy")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(vm.isCopied ? .green : .primary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    // Reselect button
                    Button(action: onNewSelection) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Capture a new region (\(GlobalShortcutManager.shared.currentCombo.displayString))")

                    // Close button
                    Button(action: onClose) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 26, height: 26)
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                .frame(width: 26, height: 26)
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.75))
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Close (Esc)")
                }
            }

            Divider()

            // Response Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8) {
                    MarkdownTextView(responseText)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 180, maxHeight: 380)

            Divider()

            // Follow-up Input
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))

                TextField("Ask a follow-up question about this image...", text: $vm.followUpText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isFollowUpFocused)
                    .onSubmit {
                        submitFollowUp()
                    }

                Button(action: submitFollowUp) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(vm.followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(vm.followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFollowUpFocused ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .padding(18)
        .frame(width: 520)
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(responseText, forType: .string)

        withAnimation {
            vm.isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak vm] in
            withAnimation {
                vm?.isCopied = false
            }
        }
    }

    private func submitFollowUp() {
        let trimmed = vm.followUpText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onFollowUp(trimmed)
        vm.followUpText = ""
    }
}
