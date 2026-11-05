import AppKit
import PeekshCore

struct ScreenChoice: Identifiable {
    let id: String
    let name: String
}

enum ScreenPlacement {
    static var choices: [ScreenChoice] {
        NSScreen.screens.map { ScreenChoice(id: identifier(for: $0), name: $0.localizedName) }
    }

    static func identifier(for screen: NSScreen) -> String {
        let display = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        if let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return "display-\(display)"
    }

    static func target(preference: ScreenPreference, preferredScreenID: String,
                       mode: PanelMode, anchor: NSRect?) -> NSScreen? {
        let screens = NSScreen.screens
        // Automatic retains the original active-screen fallback; Main Display selects the primary display.
        let main = preference == .automatic ? NSScreen.main : screens.first
        let id = ScreenSelection.screenID(preference: preference, preferredScreenID: preferredScreenID,
            mode: mode, screens: screens.map { PanelScreen(id: identifier(for: $0), frame: $0.frame) },
            mainID: main.map { identifier(for: $0) }, pointer: NSEvent.mouseLocation, anchor: anchor)
        return screens.first(where: { identifier(for: $0) == id })
    }

}
