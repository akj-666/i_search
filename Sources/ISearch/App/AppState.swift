import Foundation
import AppKit
import SwiftUI

/// Window subclass that automatically closes when Escape is pressed.
final class DismissableWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        self.close()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            self.close()
            return
        }
        super.keyDown(with: event)
    }
}

/// Central application state coordinator managing the lifecycle of selection, capture, AI queries, and panels.
@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    private let onboardingCompletedKey = "ISearch_HasCompletedOnboarding"

    // Ephemeral in-memory image capture data (released on dismiss)
    private var currentCGImage: CGImage?
    private var currentJPEGData: Data?
    private var currentSelectionRect: CGRect = .zero
    private var currentScreen: NSScreen?
    private var currentAITask: Task<Void, Never>?

    @Published public var panelState: ResultsPanelView.PanelState = .review {
        didSet {
            switch panelState {
            case .review:
                ResultsPanelController.shared.updatePanelHeight(310)
            case .loading:
                ResultsPanelController.shared.updatePanelHeight(240)
            case .response:
                ResultsPanelController.shared.updatePanelHeight(460)
            case .error:
                ResultsPanelController.shared.updatePanelHeight(300)
            }
        }
    }

    private var settingsWindow: NSWindow?

    private init() {
        setupOverlayCallbacks()
    }

    // MARK: - Selection & Capture Flow

    /// Initiates the full-screen dimmed selection overlay.
    public func startSelection() {
        // Dismiss any existing results panel before starting a new selection
        ResultsPanelController.shared.dismiss()
        clearCurrentCapture()

        SelectionOverlayController.shared.startSelection()
    }

    private func setupOverlayCallbacks() {
        SelectionOverlayController.shared.onSelectionConfirmed = { [weak self] rect, screen in
            self?.handleSelectionConfirmed(rect: rect, on: screen)
        }

        SelectionOverlayController.shared.onSelectionCanceled = { [weak self] in
            self?.clearCurrentCapture()
        }
    }

    private func handleSelectionConfirmed(rect: CGRect, on screen: NSScreen) {
        self.currentSelectionRect = rect
        self.currentScreen = screen

        Task {
            do {
                let cgImage = try await ScreenCaptureService.shared.captureRegion(appKitRect: rect, on: screen)
                self.currentCGImage = cgImage

                guard let jpegData = ImageProcessor.shared.encodeJPEG(from: cgImage) else {
                    throw ScreenCaptureService.CaptureError.invalidImageData
                }
                self.currentJPEGData = jpegData

                let thumbnail = ImageProcessor.shared.createThumbnail(from: cgImage)
                self.presentFloatingPanel(thumbnail: thumbnail, near: rect, on: screen)
            } catch {
                NSLog("[AppState] Capture error: %@", error.localizedDescription)
                self.presentErrorPanel(error: error, near: rect, on: screen)
            }
        }
    }

    // MARK: - Floating Panel Presentation

    private func presentFloatingPanel(thumbnail: NSImage, near rect: CGRect, on screen: NSScreen) {
        panelState = .review

        let panelView = ResultsPanelView(
            appState: self,
            thumbnail: thumbnail,
            providerName: AIConfiguration.shared.selectedProvider.displayName,
            onSubmitPrompt: { [weak self] prompt in
                self?.submitPrompt(prompt)
            },
            onCancelRequest: { [weak self] in
                self?.cancelCurrentAITask()
            },
            onNewSelection: { [weak self] in
                self?.startSelection()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onOpenSystemSettings: {
                PermissionManager.shared.openSystemSettings()
            },
            onRevealInFinder: {
                PermissionManager.shared.revealAppInFinder()
            },
            onSwitchToMock: { [weak self] in
                guard let self = self else { return }
                AIConfiguration.shared.selectedProvider = .mock
                self.submitPrompt("Explain what is shown in this selected image in clear, concise language.")
            },
            onClose: { [weak self] in
                self?.dismissPanel()
            }
        )

        ResultsPanelController.shared.show(content: panelView, near: rect, on: screen)
    }

    private func presentErrorPanel(error: Error, near rect: CGRect, on screen: NSScreen) {
        let isMissingPermission = (error as? ScreenCaptureService.CaptureError) == .permissionDenied
        panelState = .error(
            message: error.localizedDescription,
            type: isMissingPermission ? .missingPermission : .generic
        )

        let emptyImage = NSImage(size: NSSize(width: 80, height: 60))

        let panelView = ResultsPanelView(
            appState: self,
            thumbnail: emptyImage,
            providerName: AIConfiguration.shared.selectedProvider.displayName,
            onSubmitPrompt: { [weak self] prompt in
                self?.submitPrompt(prompt)
            },
            onCancelRequest: { },
            onNewSelection: { [weak self] in self?.startSelection() },
            onOpenSettings: { [weak self] in self?.openSettings() },
            onOpenSystemSettings: {
                PermissionManager.shared.openSystemSettings()
            },
            onRevealInFinder: {
                PermissionManager.shared.revealAppInFinder()
            },
            onSwitchToMock: { [weak self] in
                guard let self = self else { return }
                AIConfiguration.shared.selectedProvider = .mock
                self.submitPrompt("Explain what is shown in this selected image in clear, concise language.")
            },
            onClose: { [weak self] in self?.dismissPanel() }
        )

        ResultsPanelController.shared.show(content: panelView, near: rect, on: screen)
    }

    // MARK: - AI Submission & Query Lifecycle

    private func submitPrompt(_ prompt: String) {
        guard let imageData = currentJPEGData else {
            panelState = .error(message: "No captured image available for analysis.", type: .generic)
            return
        }

        panelState = .loading

        let mathGuidance = "\n\nNote: If writing mathematical equations, formulas, or matrices, format them in standard LaTeX notation ($...$ for inline or $$...$$ for display blocks) using double backslashes (\\\\) for line breaks and matrix row separators."
        let finalPrompt = prompt.contains("LaTeX notation") ? prompt : (prompt + mathGuidance)

        let provider = AIConfiguration.shared.selectedProvider
        let hasCreds = AIConfiguration.shared.hasCredentials(for: provider)

        currentAITask?.cancel()
        currentAITask = Task {
            do {
                if !hasCreds && provider != .mock {
                    // Smoothly fall back to Apple On-Device Vision OCR demo mode so the user gets an instant answer!
                    let mockService = MockAIService()
                    let result = try await mockService.analyze(image: imageData, prompt: finalPrompt, mimeType: "image/jpeg")
                    if !Task.isCancelled {
                        let providerNotice = "> 💡 *Note: \(provider.displayName) is selected, but no API key was configured. This answer was analyzed using Apple's On-Device Vision OCR. You can add your API key in **Settings (⌘,)** anytime for full cloud AI reasoning.*\n\n"
                        self.panelState = .response(text: providerNotice + result)
                    }
                    return
                }

                let service = AIConfiguration.shared.createService()
                let response = try await service.analyze(image: imageData, prompt: finalPrompt, mimeType: "image/jpeg")
                if !Task.isCancelled {
                    self.panelState = .response(text: response)
                }
            } catch is CancellationError {
                if !Task.isCancelled {
                    self.panelState = .review
                }
            } catch let error as AIError {
                if !Task.isCancelled {
                    switch error {
                    case .missingCredentials:
                        let mockService = MockAIService()
                        if let result = try? await mockService.analyze(image: imageData, prompt: finalPrompt, mimeType: "image/jpeg") {
                            let providerNotice = "> 💡 *Note: \(provider.displayName) requires an API key in Settings (⌘,). Showing instant on-device OCR analysis below:*\n\n"
                            self.panelState = .response(text: providerNotice + result)
                        } else {
                            self.panelState = .error(message: error.localizedDescription, type: .missingCredentials)
                        }
                    case .canceled:
                        self.panelState = .review
                    default:
                        self.panelState = .error(message: error.localizedDescription, type: .generic)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.panelState = .error(message: error.localizedDescription, type: .generic)
                }
            }
        }
    }

    private func cancelCurrentAITask() {
        currentAITask?.cancel()
        currentAITask = nil
        panelState = .review
    }

    public func dismissPanel() {
        cancelCurrentAITask()
        ResultsPanelController.shared.dismiss()
        clearCurrentCapture()
    }

    /// Releases all in-memory image buffers immediately.
    private func clearCurrentCapture() {
        currentCGImage = nil
        currentJPEGData = nil
        currentSelectionRect = .zero
        currentScreen = nil
    }

    // MARK: - Windows

    public func openSettings() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView { [weak self] in
            self?.settingsWindow?.orderOut(nil)
            self?.startSelection()
        }

        let newWindow = DismissableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "i search Settings"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.contentView = NSHostingView(rootView: settingsView)

        self.settingsWindow = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func checkAndShowOnboarding() {
        let hasCompleted = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        if !hasCompleted {
            showWelcome()
        }
    }

    public func showWelcome() {
        WelcomeWindowController.shared.show(
            onTestShortcut: { [weak self] in
                self?.startSelection()
            },
            onComplete: { [weak self] in
                UserDefaults.standard.set(true, forKey: self?.onboardingCompletedKey ?? "")
            }
        )
    }
}
