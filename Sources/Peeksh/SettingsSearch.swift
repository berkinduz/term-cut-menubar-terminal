import Foundation

enum SettingsSection: CaseIterable {
    case general, appearance, windows, terminal, profiles, notifications, keyboardShortcuts, defaults, about

    private var searchTerms: String {
        switch self {
        case .general:
            return "General Keep visible when switching apps Launch at login Restore workspace on launch startup pin menu bar hide visibility"
        case .appearance:
            return "Appearance Terminal theme Font Installed font Custom font Text size Terminal padding Translucent window bars Animate window transitions Dim inactive panes Show status bar color typography glass transparency motion animations "
                + TerminalTheme.allCases.map(\.rawValue).joined(separator: " ")
        case .windows:
            return "Windows Window width Window height Open on display Preferred display Remember window position automatic pointer main fixed monitor window panel size"
        case .terminal:
            return "Terminal Cursor shape Blink cursor Scrollback history Use Option as Meta New sessions inherit the current directory shell panes tabs "
                + TerminalCursor.allCases.map(\.rawValue).joined(separator: " ")
        case .keyboardShortcuts:
            return "Keyboard Shortcuts Enable global shortcuts Toggle terminal New tab Split right down Next previous pane Focus pane Find in terminal Close pane Hide terminal Select tab Duplicate tab hotkey keybind zoom"
        case .profiles:
            return "Project Profiles Save Current Layout Open Rename Delete saved workspace folders directory tabs arrangement"
        case .notifications:
            return "Notifications Notify when commands finish Minimum command duration permissions completion alerts build tests"
        case .defaults: return "Restore Defaults reset settings"
        case .about: return "About Peeksh version Made by berkinduz Source code contributions Buy me a coffee"
        }
    }

    func matches(_ query: String) -> Bool {
        let separators = CharacterSet.alphanumerics.inverted
        let terms = searchTerms.components(separatedBy: separators).joined(separator: " ")
        let words = query.components(separatedBy: separators).filter { !$0.isEmpty }
        return words.allSatisfy { terms.localizedCaseInsensitiveContains($0) }
    }
}
