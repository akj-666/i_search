import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Manages macOS Screen Recording permissions and status.
@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public private(set) var hasScreenRecordingPermission: Bool = false

    private init() {
        checkPermission()
    }

    /// Checks the current Screen Recording permission state.
    @discardableResult
    public func checkPermission() -> Bool {
        let granted = CGPreflightScreenCaptureAccess()
        self.hasScreenRecordingPermission = granted
        return granted
    }

    /// Prompts macOS to request Screen Recording access and registers the app in TCC.
    public func requestPermission() {
        // 1. Official CoreGraphics permission request
        CGRequestScreenCaptureAccess()

        // 2. Perform a 1x1 capture probe.
        // On macOS 14 & 15 (Sequoia), attempting a capture is what triggers macOS
        // to immediately prompt the user and list the app in System Settings -> Screen Recording!
        _ = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        )

        // 3. Trigger ScreenCaptureKit content discovery probe
        if #available(macOS 14.0, *) {
            Task {
                _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            }
        }

        checkPermission()
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Screen Recording.
    public func openSystemSettings() {
        // Ensure request is made first so macOS records the app bundle in TCC database
        requestPermission()

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Reveals the application bundle in Finder so the user can easily drag it into System Settings or select it with the '+' button.
    public func revealAppInFinder() {
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    }
}
