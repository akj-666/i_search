import Foundation
import Carbon
import AppKit

/// Manages system-wide global hotkeys via Carbon RegisterEventHotKey.
@MainActor
public final class GlobalShortcutManager: ObservableObject {
    public static let shared = GlobalShortcutManager()

    @Published public private(set) var currentCombo: KeyCombo = .default

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var onTriggerCallback: (() -> Void)?

    private let userDefaultsKey = "ISearch_CustomKeyCombo"
    private let hotKeySignature: OSType = 0x49535243 // 'ISRC'
    private let hotKeyIDValue: UInt32 = 1

    private init() {
        loadSavedCombo()
        setupCarbonEventHandler()
    }

    deinit {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    /// Sets the handler to call when the global shortcut is pressed.
    public func setHandler(_ callback: @escaping () -> Void) {
        self.onTriggerCallback = callback
    }

    /// Registers the current keyboard shortcut.
    @discardableResult
    public func register(combo: KeyCombo? = nil) -> Bool {
        if let combo = combo {
            self.currentCombo = combo
            saveCombo(combo)
        }

        unregister()

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIDValue)
        let status = RegisterEventHotKey(
            currentCombo.keyCode,
            currentCombo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        return status == noErr
    }

    /// Unregisters the current shortcut.
    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    /// Resets the shortcut to default (⌘⇧Space).
    public func resetToDefault() {
        _ = register(combo: .default)
    }

    // MARK: - Internal Handler

    private func setupCarbonEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if status == noErr && hotKeyID.signature == manager.hotKeySignature {
                    DispatchQueue.main.async {
                        manager.onTriggerCallback?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        if handlerStatus != noErr {
            NSLog("[GlobalShortcutManager] Failed to install Carbon event handler: %d", handlerStatus)
        }
    }

    private func loadSavedCombo() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            self.currentCombo = saved
        } else {
            self.currentCombo = .default
        }
    }

    private func saveCombo(_ combo: KeyCombo) {
        if let data = try? JSONEncoder().encode(combo) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
