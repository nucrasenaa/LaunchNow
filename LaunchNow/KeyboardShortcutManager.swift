import AppKit
import Carbon
import Combine

enum KeyboardShortcutPreset: String, CaseIterable, Identifiable {
    case disabled
    case optionSpace
    case controlSpace
    case commandShiftSpace
    case controlOptionSpace
    case commandOptionL

    var id: String { rawValue }

    var keyCode: UInt32? {
        switch self {
        case .disabled:
            return nil
        case .optionSpace, .controlSpace, .commandShiftSpace, .controlOptionSpace:
            return UInt32(kVK_Space)
        case .commandOptionL:
            return UInt32(kVK_ANSI_L)
        }
    }

    var modifierFlags: UInt32 {
        switch self {
        case .disabled:
            return 0
        case .optionSpace:
            return UInt32(optionKey)
        case .controlSpace:
            return UInt32(controlKey)
        case .commandShiftSpace:
            return UInt32(cmdKey | shiftKey)
        case .controlOptionSpace:
            return UInt32(controlKey | optionKey)
        case .commandOptionL:
            return UInt32(cmdKey | optionKey)
        }
    }
}

final class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()

    @Published private(set) var preset: KeyboardShortcutPreset

    private static let defaultsKey = "keyboardShortcutPreset"
    private static let hotKeyIDValue: UInt32 = 1
    private static let hotKeySignature = fourCharCode("LNow")

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        let rawValue = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? KeyboardShortcutPreset.optionSpace.rawValue
        preset = KeyboardShortcutPreset(rawValue: rawValue) ?? .optionSpace
    }

    deinit {
        unregisterHotKey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func start() {
        installEventHandlerIfNeeded()
        registerHotKey(for: preset)
    }

    func setPreset(_ newPreset: KeyboardShortcutPreset) {
        preset = newPreset
        UserDefaults.standard.set(newPreset.rawValue, forKey: Self.defaultsKey)
        registerHotKey(for: newPreset)
    }

    private func registerHotKey(for preset: KeyboardShortcutPreset) {
        unregisterHotKey()

        guard let keyCode = preset.keyCode else { return }

        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyIDValue)
        let status = RegisterEventHotKey(
            keyCode,
            preset.modifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            hotKeyRef = nil
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, _ in
            guard let event else { return noErr }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr,
                  hotKeyID.signature == KeyboardShortcutManager.hotKeySignature,
                  hotKeyID.id == KeyboardShortcutManager.hotKeyIDValue else {
                return noErr
            }

            DispatchQueue.main.async {
                AppDelegate.shared?.toggleWindow()
            }

            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}
