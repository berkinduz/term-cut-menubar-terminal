import PeekshCore

extension PanelMode {
    var displayName: String {
        switch self {
        case .compact: return "Floating Window"
        }
    }
}

extension ScreenPreference {
    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .pointer: return "Pointer Display"
        case .main: return "Main Display"
        case .fixed: return "Chosen Display"
        }
    }
}
