import Foundation
import XCTest
import TermCutCore
@testable import TermCut

@MainActor
final class SettingsCompatibilityTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "term-cut-settings-compatibility-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    func testOldPreferencesKeepSavedValuesWhenNewKeysAreMissing() throws {
        try withDefaults { defaults in
            defaults.set(try JSONSerialization.data(withJSONObject: [
                "theme": "Paper", "fontSize": 19, "compactWidth": 880, "keepVisible": true
            ]), forKey: "preferences")
            let settings = SettingsStore(defaults: defaults)
            XCTAssertEqual(settings.value.theme, .paper)
            XCTAssertEqual(settings.value.fontSize, 19)
            XCTAssertEqual(settings.value.compactWidth, 880)
            XCTAssertTrue(settings.value.keepVisible)
            XCTAssertTrue(settings.value.inheritDirectory)
        }
    }

    func testUnknownAndMalformedFieldsOnlyResetTheAffectedValues() throws {
        try withDefaults { defaults in
            defaults.set(try JSONSerialization.data(withJSONObject: [
                "theme": "Future Theme", "fontSize": 19, "cursor": "Block", "scrollback": "bad"
            ]), forKey: "preferences")
            let settings = SettingsStore(defaults: defaults)
            XCTAssertEqual(settings.value.theme, .kanagawaDragon)
            XCTAssertEqual(settings.value.fontSize, 19)
            XCTAssertEqual(settings.value.cursor, .block)
            XCTAssertEqual(settings.value.scrollback, 10000)
        }
    }

    func testResetUpdatesTheLiveAndRememberedWindowMode() {
        withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            let workspace = TerminalWorkspace(settings: settings)
            settings.onChange = { [weak workspace] in workspace?.applyPreferences() }
            workspace.mode = .dropDown
            settings.value.fontSize = 19
            settings.reset()
            XCTAssertEqual(workspace.mode, .compact)
            XCTAssertEqual(settings.lastWindowMode, .compact)
            XCTAssertEqual(SettingsStore(defaults: defaults).lastWindowMode, .compact)
            XCTAssertEqual(settings.value.theme, .kanagawaDragon)
            XCTAssertEqual(settings.value.fontSize, 13)
        }
    }

    func testEverySavedPreferenceSurvivesARoundTrip() {
        withDefaults { defaults in
            var preferences = AppPreferences()
            preferences.theme = .slate
            preferences.font = .custom
            preferences.customFontName = "Monaco"
            preferences.fontSize = 18
            preferences.cursor = .block
            preferences.cursorBlinks = true
            preferences.compactWidth = 900
            preferences.compactHeight = 600
            preferences.dropDownHeight = 0.65
            preferences.dropDownWidth = 0.8
            preferences.menuBarMode = .dropDown
            preferences.keepVisible = true
            preferences.showOnLaunch = false
            preferences.optionAsMeta = true
            preferences.scrollback = 25000
            preferences.animationsEnabled = false
            preferences.glassEnabled = false
            preferences.dimInactivePanes = false
            preferences.showStatusBar = false
            preferences.terminalPadding = 18
            preferences.inheritDirectory = false
            preferences.shortcutsEnabled = false
            preferences.compactShortcut = GlobalShortcut(keyCode: 48, modifiers: 256, key: "Tab")
            preferences.dropDownShortcut = GlobalShortcut(keyCode: 36, modifiers: 512, key: "Return")
            SettingsStore(defaults: defaults).value = preferences
            XCTAssertEqual(SettingsStore(defaults: defaults).value, preferences)
        }
    }
}
