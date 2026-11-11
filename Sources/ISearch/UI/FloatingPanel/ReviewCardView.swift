import SwiftUI
import AppKit

@MainActor
public final class ReviewCardViewModel: ObservableObject {
    @Published public var searchQuery: String = ""

    public init() {}
}

/// Google Circle to Search style floating review card with a free-text search box.
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
            // Header Row: Thumbnail + App info + Close Button
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 120, maxHeight: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 15))
                        Text("i search")
                            .font(.system(size: 13, weight: .bold))
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                        Text(providerName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text("Selected content ready")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Search item or ask a question in context")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color(NSColor.controlBackgroundColor)))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }

            Divider()

            // Google Circle to Search - Free-Text Search Box
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14, weight: .medium))

                    TextField("Search or ask anything about this...", text: $vm.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            submitCurrentPrompt()
                        }

                    if !vm.searchQuery.isEmpty {
                        Button(action: { vm.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                    }

                    // Integrated Search / Enter Button
                    Button(action: submitCurrentPrompt) {
                        HStack(spacing: 4) {
                            Text(isQueryEmpty ? "Search" : "Ask")
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .help(isQueryEmpty ? "Search selected item (Return)" : "Ask question about item (Return)")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isTextFieldFocused ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1.5)
                )

                // Contextual Guidance Hint
                HStack(spacing: 5) {
                    Image(systemName: isQueryEmpty ? "sparkles" : "bubble.left.and.bubble.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    if isQueryEmpty {
                        Text("Press **Return** to search and explain what is selected.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Will answer your question in simple, clear language.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            // Quick Example Chips (e.g. for inspiration like Circle to Search)
            HStack(spacing: 6) {
                examplePill("Is it safe for cats?")
                examplePill("What is this?")
                examplePill("Transcribe text")
                examplePill("Where to buy?")
            }

            // Privacy / Storage Notice
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 9))
                Text("In-memory only. The original screen remains underneath.")
                    .font(.system(size: 9))
            }
            .foregroundColor(.secondary)

            Divider()

            // Footer Navigation Actions
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
                        Image(systemName: isQueryEmpty ? "magnifyingglass" : "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text(isQueryEmpty ? "Search Selection" : "Search in Context")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 460)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private var isQueryEmpty: Bool {
        vm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func examplePill(_ text: String) -> some View {
        Button(action: {
            vm.searchQuery = text
            submitPromptWithText(text)
        }) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                )
                .overlay(
                    Capsule()
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func submitPromptWithText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let prompt = "The user selected an area on their screen and asks: \"\(trimmed)\"\n\nUsing the selected visual content and surrounding context, answer the user's question directly. Use simple, clear, and easy-to-understand language. Provide specific, accurate, and helpful information. If writing mathematical equations, matrices, or formulas, format them using standard LaTeX notation ($...$ for inline or $$...$$ for display blocks) with double backslashes (\\\\) for line breaks and matrix row separators."
            onSubmit(prompt)
        } else {
            submitCurrentPrompt()
        }
    }

    private func submitCurrentPrompt() {
        let trimmed = vm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            // With a question:
            let prompt = "The user selected an area on their screen and asks: \"\(trimmed)\"\n\nUsing the selected visual content and surrounding context, answer the user's question directly. Use simple, clear, and easy-to-understand language. Provide specific, accurate, and helpful information. If writing mathematical equations, matrices, or formulas, format them using standard LaTeX notation ($...$ for inline or $$...$$ for display blocks) with double backslashes (\\\\) for line breaks and matrix row separators."
            onSubmit(prompt)
        } else {
            // Without a question:
            let prompt = "Identify and provide comprehensive, relevant information or search results about the selected item in context. Explain what it is, its key details, specifications, background, or function, and any helpful context in simple, clear language. If writing mathematical equations, matrices, or formulas, format them using standard LaTeX notation ($...$ for inline or $$...$$ for display blocks) with double backslashes (\\\\) for line breaks and matrix row separators."
            onSubmit(prompt)
        }
    }
}
