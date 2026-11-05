import CoreGraphics

public struct PanelScreen {
    public var id: String
    public var frame: CGRect

    public init(id: String, frame: CGRect) { self.id = id; self.frame = frame }
}

public enum ScreenSelection {
    public static func screenID(preference: ScreenPreference, preferredScreenID: String,
                                mode: PanelMode, screens: [PanelScreen], mainID: String?,
                                pointer: CGPoint, anchor: CGRect?) -> String? {
        let fallback = screens.first(where: { $0.id == mainID })?.id ?? screens.first?.id
        let pointerID = screens.first(where: { $0.frame.contains(pointer) })?.id
        switch preference {
        case .automatic:
            return screens.first(where: { screen in anchor.map { $0.intersects(screen.frame) } ?? false })?.id ?? fallback
        case .pointer: return pointerID ?? fallback
        case .main: return fallback
        case .fixed: return screens.first(where: { $0.id == preferredScreenID })?.id ?? fallback
        }
    }
}
