import SwiftUI
import AppKit

@MainActor
public final class ReviewCardViewModel: ObservableObject {
    @Published public var selectedAction: QuickAction = .explain
    @Published public var customQuestion: String = ""

    public init() {}
}

/// Card view for reviewing captured region and choosing an action/prompt.
public struct ReviewCardView: View {
    public let thumbnail: NSImage
    public let providerName: String
    public let onSubmit: (String) -> Void
    public let onNewSelection: () -> Void
    public let onCancel: () -> Void

    @StateObject private var vm = ReviewCardViewModel()
    @FocusState private var isTextFieldFocused: Bool

    public init(
        thumbnail: NSImage,
        providerName: String,
        onSubmit: @escaping (String) -> Void,
        onNewSelection: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.thumbnail = thumbnail
        self.providerName = providerName
        self.onSubmit = onSubmit
        self.onNewSelection = onNewSelection
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Thumbnail + Meta
            HStack(spacing: 12) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 130, maxHeight: 85)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        Text("i search")
                            .font(.system(size: 13, weight: .bold))
                    }

                    Text("Selected region captured")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("Ready for AI analysis via \(providerName)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            Divider()

            // Quick Actions Chips
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose action")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ActionChip(
                        title: "Explain this",
                        iconName: "sparkles",
                        isSelected: vm.selectedAction == .explain
                    ) {
                        vm.selectedAction = .explain
                    }

                    ActionChip(
                        title: "Read text",
                        iconName: "doc.text.viewfinder",
                        isSelected: vm.selectedAction == .readText
                    ) {
                        vm.selectedAction = .readText
                    }

                    ActionChip(
                        title: "Identify",
                        iconName: "tag",
                        isSelected: vm.selectedAction == .identify
                    ) {
                        vm.selectedAction = .identify
                    }
                }
            }

            // Custom Question Input
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Or ask a specific question:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))

                    TextField("What would you like to know about this?", text: $vm.customQuestion)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            submitCurrentPrompt()
                        }

                    if !vm.customQuestion.isEmpty {
                        Button(action: { vm.customQuestion = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isTextFieldFocused ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1)
                )
            }

            // Privacy Notice
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 9))
                Text("Image is sent only upon submission. Nothing is saved to disk.")
                    .font(.system(size: 9))
            }
            .foregroundColor(.secondary)

            // Action Buttons
            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 12))
                }
                .keyboardShortcut(.cancelAction)

                Button(action: onNewSelection) {
                    Label("Reselect", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                }

                Spacer()

                Button(action: submitCurrentPrompt) {
                    HStack(spacing: 6) {
                        Text(submitButtonTitle)
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 440)
    }

    private var submitButtonTitle: String {
        if !vm.customQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ask Question"
        }
        return vm.selectedAction.rawValue
    }

    private func submitCurrentPrompt() {
        let trimmed = vm.customQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onSubmit(trimmed)
        } else {
            onSubmit(vm.selectedAction.defaultPrompt)
        }
    }
}
