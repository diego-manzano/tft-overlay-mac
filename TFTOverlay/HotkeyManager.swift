import Carbon.HIToolbox
import Foundation

/// Global ⌥Space hotkey via Carbon — works without Accessibility permission.
final class HotkeyManager {
    static let shared = HotkeyManager()
    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?

    func register(handler: @escaping () -> Void) {
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                Unmanaged<HotkeyManager>.fromOpaque(userData)
                    .takeUnretainedValue().handler?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x5446_544F), id: 1) // "TFTO"
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
