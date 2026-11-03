import Foundation

enum SettingsSection: CaseIterable {
    case general, appearance, windows, terminal, keyboardShortcuts, defaults, about

    private var searchTerms: String {
        switch self {
        case .general:
            return "General Window mode Floating Window Top Drawer Compact panel Drop-down terminal Show terminal on launch Keep visible when switching apps Launch at login startup pin menu bar hide visibility"
        case .appearance:
            return "Appearance Terminal theme Font Installed font Custom font Text size Terminal padding Translucent window bars Animate window transitions Dim inactive panes Show status bar color typography glass transparency motion animations "
                + TerminalTheme.allCases.map(\.rawValue).joined(separator: " ")
        case .windows:
            return "Windows Floating window width Floating window height Drawer width Drawer height Compact width Compact height Drop-down width Drop-down height window panel dropdown size"
        case .terminal:
            return "Terminal Cursor shape Blink cursor Scrollback history Use Option as Meta New sessions inherit the current directory shell panes tabs "
                + TerminalCursor.allCases.map(\.rawValue).joined(separator: " ")
        case .keyboardShortcuts:
            return "Keyboard Shortcuts Enable global shortcuts Toggle floating window Toggle top drawer Toggle compact panel Toggle drop-down terminal New tab Split right down Next previous pane Focus pane Find in terminal Close pane Hide terminal hotkey keybind zoom"
        case .defaults: return "Restore Defaults reset settings"
        case .about: return "About term-cut version Made by berkinduz Source code contributions Buy me a coffee"
        }
    }

    func matches(_ query: String) -> Bool {
        let separators = CharacterSet.alphanumerics.inverted
        let terms = searchTerms.components(separatedBy: separators).joined(separator: " ")
        let words = query.components(separatedBy: separators).filter { !$0.isEmpty }
        return words.allSatisfy { terms.localizedCaseInsensitiveContains($0) }
    }
}
