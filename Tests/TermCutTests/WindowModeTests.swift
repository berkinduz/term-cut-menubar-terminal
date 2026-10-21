import XCTest
import TermCutCore
@testable import TermCut

@MainActor
final class WindowModeTests: XCTestCase {
    func testLastUsedModeSurvivesRestartAndUnrelatedPreferenceChanges() {
        let suite = "term-cut-mode-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.value.menuBarMode = .dropDown
        let workspace = TerminalWorkspace(settings: settings)
        XCTAssertEqual(workspace.mode, .dropDown)

        workspace.mode = .compact
        settings.value.theme = .paper
        settings.value.fontSize = 16
        workspace.applyPreferences()
        let reopened = TerminalWorkspace(settings: SettingsStore(defaults: UserDefaults(suiteName: suite)!))
        XCTAssertEqual(reopened.mode, .compact)

        reopened.mode = .dropDown
        let restarted = TerminalWorkspace(settings: SettingsStore(defaults: UserDefaults(suiteName: suite)!))
        XCTAssertEqual(restarted.mode, .dropDown)
    }
}
