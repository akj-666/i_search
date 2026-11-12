import SwiftUI
import AppKit

@MainActor
public final class ReviewCardViewModel: ObservableObject {
    @Published public var searchQuery: String = ""

    public init() {}
}

/// Floating review card matching the refined i search design with subtle Liquid Glass styling.
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
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Top Header Row (Thumbnail + Brand & Titles + Close Button)
            HStack(alignment: .top, spacing: 18) {
                // Content Thumbnail Container
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.05, green: 0.07, blue: 0.11))

                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(4)

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .frame(width: 136, height: 84)

                // Info Titles Block
                VStack(alignment: .leading, spacing: 5) {
                    // App Brand & AI Provider line
                    HStack(spacing: 7) {
                        AppIconView(size: 20)

                        Text("i search")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)

                        Text("•")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.35))

                        Text(providerName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.65))
                            .lineLimit(1)
                    }

                    // Main Status Headline
                    Text("Selected content ready")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 1)

                    // Subtitle / Instructional Guide
                    Text("Search what you see, or ask a question in context.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(red: 0.58, green: 0.65, blue: 0.74))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                // Top-Right Circular Close Control
                Button(action: onCancel) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 28, height: 28)

                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            .frame(width: 28, height: 28)

                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }

            // MARK: - Upper Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.vertical, 14)

            // MARK: - Middle Section: Search & Prompt Box
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ask about your selection")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Add a question or search phrase, or leave it blank for an overview.")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(Color(red: 0.54, green: 0.60, blue: 0.70))
                }

                // Interactive Search Pill
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.42, green: 0.52, blue: 0.68))
                        .padding(.leading, 6)

                    ZStack(alignment: .leading) {
                        if vm.searchQuery.isEmpty {
                            Text("What would you like to know about this?")
                                .font(.system(size: 13.5, weight: .regular))
                                .foregroundColor(Color(red: 0.40, green: 0.48, blue: 0.58))
                        }

                        TextField("", text: $vm.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundColor(.white)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                submitCurrentPrompt()
                            }
                    }

                    if !vm.searchQuery.isEmpty {
                        Button(action: { vm.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color.white.opacity(0.45))
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    // Integrated Action Button ("Search →")
                    Button(action: submitCurrentPrompt) {
                        HStack(spacing: 6) {
                            Text("Search")
                                .font(.system(size: 13, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(Color(red: 0.17, green: 0.44, blue: 0.98))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Search (Return)")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(red: 0.045, green: 0.065, blue: 0.10).opacity(0.90))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color(red: 0.17, green: 0.44, blue: 0.98), lineWidth: 1.5)
                )
            }

            // MARK: - Lower Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.vertical, 14)

            // MARK: - Bottom Privacy Information Note
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(red: 0.48, green: 0.55, blue: 0.65))

                Text("Your selection stays on this screen while iSearch finds relevant results.")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(Color(red: 0.48, green: 0.55, blue: 0.65))

                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(width: 520)
        .onAppear {
            isTextFieldFocused = true
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
