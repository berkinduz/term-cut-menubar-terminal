import TermCutCore

extension PanelMode {
    var displayName: String { self == .compact ? "Floating Window" : "Top Drawer" }
    var toolbarName: String { self == .compact ? "Window" : "Drawer" }
}
