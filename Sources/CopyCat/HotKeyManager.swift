import Foundation
import Carbon.HIToolbox

/// Registers a system-wide hotkey via Carbon. This works without Accessibility
/// or Input-Monitoring permission, unlike `NSEvent` global monitors.
final class HotKeyManager {
    // Common key codes / modifier masks for convenience.
    static let keyV = UInt32(kVK_ANSI_V)
    static let optionCommand = UInt32(optionKey | cmdKey)

    let callback: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.callback = callback

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(),
                            hotKeyEventHandler, 1, &eventType, selfPtr, &eventHandler)

        // 'CCSH' signature, id 1.
        let hotKeyID = EventHotKeyID(signature: 0x4343_5348, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    fileprivate func fire() {
        callback()
    }
}

/// Top-level C callback Carbon invokes on the main run loop when the hotkey fires.
private func hotKeyEventHandler(_ next: EventHandlerCallRef?,
                               _ event: EventRef?,
                               _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue().fire()
    return noErr
}
