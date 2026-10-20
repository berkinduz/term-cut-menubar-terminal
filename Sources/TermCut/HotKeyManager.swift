import AppKit
import Carbon
import TermCutCore

final class HotKeyManager: ObservableObject {
    @Published private(set) var error: String?
    var onShortcut: ((PanelMode) -> Void)?
    private var handler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []
    private var registered: [GlobalShortcut] = []
    private let signature: OSType = 0x54435554

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                          nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == manager.signature else { return OSStatus(eventNotHandledErr) }
            manager.onShortcut?(identifier.id == 1 ? .compact : .dropDown)
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    func update(_ preferences: AppPreferences) {
        let desired = preferences.shortcutsEnabled ? [preferences.compactShortcut, preferences.dropDownShortcut] : []
        guard desired != registered else { return }
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys = []
        registered = desired
        error = nil
        for (index, shortcut) in desired.enumerated() {
            var reference: EventHotKeyRef?
            let identifier = EventHotKeyID(signature: signature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, identifier, GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference { hotKeys.append(reference) }
            else { error = "\(shortcut.label) is unavailable. Choose a different shortcut." }
        }
    }

    deinit {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }
}
