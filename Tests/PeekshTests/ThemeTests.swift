import AppKit
import XCTest
import PeekshCore
@testable import Peeksh

@MainActor
final class ThemeTests: XCTestCase {
    func testFreshSettingsAndRestoreDefaultsUseKanagawaDragon() {
        let suite = "peeksh-theme-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.value.theme.rawValue, "Kanagawa Dragon")

        settings.value.theme = .paper
        settings.reset()
        XCTAssertEqual(SettingsStore(defaults: defaults).value.theme.rawValue, "Kanagawa Dragon")
    }

    func testSavedThemeAndFontSurviveLoadingWithTheNewDefault() {
        let suite = "peeksh-saved-theme-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.value.theme = .midnight
        settings.value.fontSize = 17
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.value.theme, .midnight)
        XCTAssertEqual(reloaded.value.fontSize, 17)
    }

    func testDefaultPaletteReachesTheTerminalAndLiveThemeChangesKeepItsProcess() {
        _ = NSApplication.shared
        let configuration = ShellConfiguration(shell: "/bin/zsh", home: "/tmp", inheritedEnvironment: [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "ZDOTDIR": "/dev/null", "HISTFILE": "/dev/null"
        ], arguments: ["-f"])
        let session = TerminalSession(configuration: configuration, preferences: AppPreferences())
        defer { session.stop() }
        let pid = session.terminal.process.shellPid
        XCTAssertEqual(session.terminal.nativeBackgroundColor, NSColor(hex: 0x181616))
        XCTAssertEqual(session.terminal.nativeForegroundColor, NSColor(hex: 0xC5C9C5))
        XCTAssertEqual(session.terminal.selectedTextBackgroundColor, NSColor(hex: 0x223249))

        var preferences = AppPreferences()
        preferences.theme = .paper
        session.apply(preferences)
        session.apply(AppPreferences())
        XCTAssertEqual(session.terminal.nativeBackgroundColor, NSColor(hex: 0x181616))
        XCTAssertEqual(session.terminal.process.shellPid, pid)
        XCTAssertTrue(session.terminal.process.running)
    }
}
