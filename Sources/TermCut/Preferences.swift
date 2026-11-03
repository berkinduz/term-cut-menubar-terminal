import AppKit
import Carbon
import Combine
import TermCutCore

struct GlobalShortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String

    static let compact = GlobalShortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey), key: "Space")
    static let dropDown = GlobalShortcut(keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(controlKey | optionKey), key: "`")

    var label: String {
        var text = ""
        for (flag, symbol) in [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")] {
            if modifiers & UInt32(flag) != 0 { text += symbol }
        }
        return text + key
    }
}

enum TerminalTheme: String, Codable, CaseIterable, Identifiable {
    case kanagawaDragon = "Kanagawa Dragon"
    case midnight = "Midnight"
    case slate = "Slate"
    case paper = "Paper"
    var id: String { rawValue }

    var background: NSColor {
        switch self {
        case .kanagawaDragon: return NSColor(hex: 0x181616)
        case .midnight: return NSColor(hex: 0x14181E)
        case .slate: return NSColor(hex: 0x252B34)
        case .paper: return NSColor(hex: 0xF7F6F2)
        }
    }
    var foreground: NSColor {
        if self == .kanagawaDragon { return NSColor(hex: 0xC5C9C5) }
        return NSColor(hex: self == .paper ? 0x30363D : 0xD9E1EA)
    }
    var accent: NSColor {
        if self == .kanagawaDragon { return NSColor(hex: 0x8BA4B0) }
        return NSColor(hex: self == .paper ? 0x157467 : 0x82CDBB)
    }
    var secondary: NSColor {
        if self == .kanagawaDragon { return NSColor(hex: 0xA6A69C) }
        return NSColor(hex: self == .paper ? 0x66736F : 0x8E9BA9)
    }
    var selection: NSColor {
        self == .kanagawaDragon ? NSColor(hex: 0x223249) : accent.withAlphaComponent(0.3)
    }
    var chrome: NSColor {
        switch self {
        case .kanagawaDragon: return NSColor(hex: 0x0D0C0C)
        case .midnight: return NSColor(hex: 0x1B2028)
        case .slate: return NSColor(hex: 0x2C333E)
        case .paper: return NSColor(hex: 0xEEEEE8)
        }
    }
    var ansi: [UInt32] {
        if self == .kanagawaDragon {
            return [0x0D0C0C, 0xC4746E, 0x8A9A7B, 0xC4B28A, 0x8BA4B0, 0xA292A3, 0x8EA4A2, 0xC8C093,
                    0xA6A69C, 0xE46876, 0x87A987, 0xE6C384, 0x7FB4CA, 0x938AA9, 0x7AA89F, 0xC5C9C5]
        }
        return self == .paper
            ? [0x30363D, 0xB43C46, 0x37753B, 0x936B16, 0x3168B0, 0x8C4EB0, 0x247D80, 0xD0D0C7,
               0x69746C, 0xCD4854, 0x428747, 0xA67A19, 0x407DCC, 0xA05FC5, 0x299495, 0xFFFFFF]
            : [0x252B34, 0xE88388, 0xA0CC9B, 0xE5CA8B, 0x8AB5E5, 0xC2A0DB, 0x83CBC7, 0xD9E1EA,
               0x738090, 0xF49A9F, 0xB8DDB0, 0xF2DDA4, 0xA5CDF4, 0xD7B7EE, 0xA2DEDA, 0xF5F7FA]
    }
}

enum TerminalFont: String, Codable, CaseIterable, Identifiable {
    case system = "SF Mono"
    case menlo = "Menlo"
    case monaco = "Monaco"
    case courier = "Courier"
    case custom = "Custom font"
    var id: String { rawValue }
    func font(size: Double, customName: String = "Menlo-Regular") -> NSFont {
        if self == .system { return .monospacedSystemFont(ofSize: size, weight: .regular) }
        return NSFont(name: self == .custom ? customName : rawValue, size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

enum FontCatalog {
    static let monospacedFonts: [String] = NSFontManager.shared.availableFonts.filter { name in
        guard let font = NSFont(name: name, size: 13) else { return false }
        return font.isFixedPitch
    }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
}

enum TerminalCursor: String, Codable, CaseIterable, Identifiable {
    case block = "Block"
    case underline = "Underline"
    case bar = "Bar"
    var id: String { rawValue }
}

struct AppPreferences: Codable, Equatable {
    var theme: TerminalTheme = .kanagawaDragon
    var font: TerminalFont = .system
    var customFontName: String = "Menlo-Regular"
    var fontSize: Double = 13
    var cursor: TerminalCursor = .bar
    var cursorBlinks: Bool = false
    var compactWidth: Double = 760
    var compactHeight: Double = 460
    var dropDownHeight: Double = 0.5
    var dropDownWidth: Double = 1
    var menuBarMode: PanelMode = .compact
    var keepVisible: Bool = false
    var showOnLaunch: Bool = true
    var optionAsMeta: Bool = false
    var scrollback: Int = 10000
    var animationsEnabled: Bool = true
    var glassEnabled: Bool = true
    var dimInactivePanes: Bool = true
    var showStatusBar: Bool = true
    var terminalPadding: Double = 12
    var inheritDirectory: Bool = true
    var shortcutsEnabled: Bool = true
    var compactShortcut: GlobalShortcut = .compact
    var dropDownShortcut: GlobalShortcut = .dropDown

    init() {}

    private enum CodingKeys: String, CodingKey {
        case theme, font, customFontName, fontSize, cursor, cursorBlinks
        case compactWidth, compactHeight, dropDownHeight, dropDownWidth, menuBarMode
        case keepVisible, showOnLaunch, optionAsMeta, scrollback, animationsEnabled, glassEnabled
        case dimInactivePanes, showStatusBar, terminalPadding, inheritDirectory, shortcutsEnabled
        case compactShortcut, dropDownShortcut
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // One missing or unreadable field must not discard the other saved settings.
        theme = (try? values.decode(TerminalTheme.self, forKey: .theme)) ?? theme
        font = (try? values.decode(TerminalFont.self, forKey: .font)) ?? font
        customFontName = (try? values.decode(String.self, forKey: .customFontName)) ?? customFontName
        fontSize = (try? values.decode(Double.self, forKey: .fontSize)) ?? fontSize
        cursor = (try? values.decode(TerminalCursor.self, forKey: .cursor)) ?? cursor
        cursorBlinks = (try? values.decode(Bool.self, forKey: .cursorBlinks)) ?? cursorBlinks
        compactWidth = (try? values.decode(Double.self, forKey: .compactWidth)) ?? compactWidth
        compactHeight = (try? values.decode(Double.self, forKey: .compactHeight)) ?? compactHeight
        dropDownHeight = (try? values.decode(Double.self, forKey: .dropDownHeight)) ?? dropDownHeight
        dropDownWidth = (try? values.decode(Double.self, forKey: .dropDownWidth)) ?? dropDownWidth
        menuBarMode = (try? values.decode(PanelMode.self, forKey: .menuBarMode)) ?? menuBarMode
        keepVisible = (try? values.decode(Bool.self, forKey: .keepVisible)) ?? keepVisible
        showOnLaunch = (try? values.decode(Bool.self, forKey: .showOnLaunch)) ?? showOnLaunch
        optionAsMeta = (try? values.decode(Bool.self, forKey: .optionAsMeta)) ?? optionAsMeta
        scrollback = (try? values.decode(Int.self, forKey: .scrollback)) ?? scrollback
        animationsEnabled = (try? values.decode(Bool.self, forKey: .animationsEnabled)) ?? animationsEnabled
        glassEnabled = (try? values.decode(Bool.self, forKey: .glassEnabled)) ?? glassEnabled
        dimInactivePanes = (try? values.decode(Bool.self, forKey: .dimInactivePanes)) ?? dimInactivePanes
        showStatusBar = (try? values.decode(Bool.self, forKey: .showStatusBar)) ?? showStatusBar
        terminalPadding = (try? values.decode(Double.self, forKey: .terminalPadding)) ?? terminalPadding
        inheritDirectory = (try? values.decode(Bool.self, forKey: .inheritDirectory)) ?? inheritDirectory
        shortcutsEnabled = (try? values.decode(Bool.self, forKey: .shortcutsEnabled)) ?? shortcutsEnabled
        compactShortcut = (try? values.decode(GlobalShortcut.self, forKey: .compactShortcut)) ?? compactShortcut
        dropDownShortcut = (try? values.decode(GlobalShortcut.self, forKey: .dropDownShortcut)) ?? dropDownShortcut
    }
}

final class SettingsStore: ObservableObject {
    @Published var value: AppPreferences {
        didSet {
            if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "preferences") }
            onChange?()
        }
    }
    var onChange: (() -> Void)?
    private let defaults: UserDefaults

    var lastWindowMode: PanelMode {
        get { defaults.string(forKey: "lastWindowMode").flatMap(PanelMode.init(rawValue:)) ?? value.menuBarMode }
        set { defaults.set(newValue.rawValue, forKey: "lastWindowMode") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "preferences"), let saved = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            value = saved
        } else {
            value = AppPreferences()
        }
    }

    func reset() {
        defaults.removeObject(forKey: "lastWindowMode")
        value = AppPreferences()
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
