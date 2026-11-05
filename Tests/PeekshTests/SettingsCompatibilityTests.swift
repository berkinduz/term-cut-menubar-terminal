import Foundation
import XCTest
import PeekshCore
@testable import Peeksh

@MainActor
final class SettingsCompatibilityTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "peeksh-settings-compatibility-\(UUID().uuidString)"
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
            XCTAssertTrue(settings.value.restoreWorkspace)
            XCTAssertTrue(settings.value.rememberWindowPosition)
            XCTAssertEqual(settings.value.screenPreference, .automatic)
            XCTAssertFalse(settings.value.commandNotificationsEnabled)
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

    func testRetiredLayoutSettingsDoNotDiscardSavedWindowAndAppearance() throws {
        try withDefaults { defaults in
            defaults.set(try JSONSerialization.data(withJSONObject: [
                "theme": "Paper", "fontSize": 19, "menuBarMode": "dropDown",
                "dropDownWidth": 0.8, "dropDownHeight": 0.7,
                "islandWidth": 0.9, "islandHeight": 0.6,
                "compactWidth": 880, "compactHeight": 510
            ]), forKey: "preferences")
            defaults.set("dropDown", forKey: "lastWindowMode")
            let settings = SettingsStore(defaults: defaults)
            XCTAssertEqual(settings.lastWindowMode, .compact)
            XCTAssertEqual(settings.value.compactWidth, 880)
            XCTAssertEqual(settings.value.compactHeight, 510)
            XCTAssertEqual(settings.value.theme, .paper)
            XCTAssertEqual(settings.value.fontSize, 19)
            settings.value.compactWidth = 940
            let reloaded = SettingsStore(defaults: defaults)
            XCTAssertEqual(reloaded.value.compactWidth, 940)
            XCTAssertEqual(reloaded.value.compactHeight, 510)
        }
    }

    func testResetUpdatesTheLiveAndRememberedWindowMode() {
        withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            let workspace = TerminalWorkspace(settings: settings)
            settings.onChange = { [weak workspace] in workspace?.applyPreferences() }
            workspace.mode = .compact
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
            preferences.keepVisible = true
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
            preferences.restoreWorkspace = false
            preferences.rememberWindowPosition = false
            preferences.screenPreference = .fixed
            preferences.preferredScreenID = "external-display"
            preferences.commandNotificationsEnabled = true
            preferences.notificationMinimumDuration = 30
            SettingsStore(defaults: defaults).value = preferences
            XCTAssertEqual(SettingsStore(defaults: defaults).value, preferences)
        }
    }
}
