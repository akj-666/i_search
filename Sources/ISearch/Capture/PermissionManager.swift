import Foundation
import AppKit
import CoreGraphics

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

    /// Prompts macOS to request Screen Recording access if not already granted.
    public func requestPermission() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
        checkPermission()
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Screen Recording.
    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
