import SwiftUI
import AppKit
import WebKit

/// Observable view model tracking content height without using the @State macro.
@MainActor
public final class MarkdownTextViewModel: ObservableObject {
    @Published public var dynamicHeight: CGFloat = 160
    public init() {}
}

/// Unified markdown and LaTeX math renderer with native macOS typography.
/// Renders standard Markdown along with inline equations ($...$, \(...\)), display equations ($$...$$, \[...\]),
/// and matrices (\begin{bmatrix}...) using bundled KaTeX and Marked.
public struct MarkdownTextView: View {
    public let markdown: String
    @StateObject private var vm = MarkdownTextViewModel()

    public init(_ markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        MarkdownMathWebView(markdown: markdown, dynamicHeight: $vm.dynamicHeight)
            .frame(height: max(vm.dynamicHeight, 60))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// AppKit NSViewRepresentable hosting a WKWebView configured for zero-network local LaTeX/Markdown rendering.
public struct MarkdownMathWebView: NSViewRepresentable {
    public let markdown: String
    @Binding public var dynamicHeight: CGFloat

    public init(markdown: String, dynamicHeight: Binding<CGFloat>) {
        self.markdown = markdown
        self._dynamicHeight = dynamicHeight
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "contentHeight")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Transparent background so the floating panel vibrancy shines through
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear

        context.coordinator.webView = webView

        // Locate local math renderer index.html
        if let htmlURL = findMathRendererURL() {
            let baseDir = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseDir)
        } else {
            webView.loadHTMLString(fallbackHTML(for: markdown), baseURL: nil)
        }

        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateContent(markdown)
    }

    private func findMathRendererURL() -> URL? {
        // 1. App Bundle Resources
        if let bundleURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "math") {
            return bundleURL
        }
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("math/index.html"),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }
        // 2. Relative to executable inside .app bundle
        let execBundle = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/math/index.html")
        if FileManager.default.fileExists(atPath: execBundle.path) {
            return execBundle
        }
        // 3. Development / Project Root
        let currentDir = FileManager.default.currentDirectoryPath
        let projectURL = URL(fileURLWithPath: currentDir).appendingPathComponent("Resources/math/index.html")
        if FileManager.default.fileExists(atPath: projectURL.path) {
            return projectURL
        }
        return nil
    }

    private func fallbackHTML(for text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
        return """
        <!DOCTYPE html><html><body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:13px;line-height:1.55;color:#1d1d1f;background:transparent;">
        \(escaped)
        </body></html>
        """
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MarkdownMathWebView
        weak var webView: WKWebView?
        private var isLoaded: Bool = false
        private var pendingMarkdown: String?
        private var lastRenderedMarkdown: String?

        init(_ parent: MarkdownMathWebView) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            let textToRender = pendingMarkdown ?? parent.markdown
            sendRenderCommand(textToRender)
        }

        public func updateContent(_ markdown: String) {
            guard markdown != lastRenderedMarkdown else { return }
            if isLoaded {
                sendRenderCommand(markdown)
            } else {
                pendingMarkdown = markdown
            }
        }

        private func sendRenderCommand(_ text: String) {
            guard let webView = webView else { return }
            lastRenderedMarkdown = text
            pendingMarkdown = nil

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: [text], options: [])
                if let jsonString = String(data: jsonData, encoding: .utf8),
                   jsonString.hasPrefix("[") && jsonString.hasSuffix("]") {
                    let startIndex = jsonString.index(after: jsonString.startIndex)
                    let endIndex = jsonString.index(before: jsonString.endIndex)
                    let stringLiteral = String(jsonString[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)

                    let js = "renderContent(\(stringLiteral));"
                    webView.evaluateJavaScript(js, completionHandler: nil)
                }
            } catch {
                NSLog("[MarkdownTextView] JSON serialization error: %@", error.localizedDescription)
            }
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "contentHeight", let heightNumber = message.body as? NSNumber {
                let height = CGFloat(heightNumber.doubleValue)
                if abs(height - parent.dynamicHeight) > 3.0 && height > 20 {
                    DispatchQueue.main.async {
                        self.parent.dynamicHeight = height
                    }
                }
            }
        }

        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
