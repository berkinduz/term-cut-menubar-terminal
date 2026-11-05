import XCTest
@testable import Peeksh

final class SettingsSearchTests: XCTestCase {
    func testVisibleLabelsAndThemeNamesFindTheirSections() {
        let examples: [(SettingsSection, String)] = [
            (.general, "Keep visible when switching apps"),
            (.general, "Launch at login"), (.appearance, "Terminal theme"),
            (.general, "Restore workspace on launch"),
            (.windows, "Open on display"), (.windows, "Remember window position"),
            (.profiles, "Save Current Layout"), (.notifications, "Minimum command duration"),
            (.appearance, "TEXT SIZE"), (.appearance, "Kanagawa Dragon"),
            (.appearance, "Translucent window bars"),
            (.windows, "Window width"), (.windows, "Window height"),
            (.terminal, "Cursor shape"), (.terminal, "Use Option as Meta"),
            (.terminal, "New sessions inherit the current directory"),
            (.keyboardShortcuts, "New tab"), (.keyboardShortcuts, "Close pane"),
            (.keyboardShortcuts, "Split right / down"), (.keyboardShortcuts, "Next / previous pane"),
            (.defaults, "Restore Defaults"), (.about, "About Peeksh")
        ]
        for (section, query) in examples {
            XCTAssertTrue(section.matches(query), "Missing search result for \(query)")
        }
    }

    func testWhitespaceAndWordOrderDoNotHideMatchingSettings() {
        XCTAssertTrue(SettingsSection.general.matches("  visible\n keep  "))
        XCTAssertTrue(SettingsSection.allCases.allSatisfy { $0.matches(" \n ") })
    }

    func testUnrelatedQueriesHaveNoResults() {
        XCTAssertFalse(SettingsSection.windows.matches("font size"))
        XCTAssertFalse(SettingsSection.allCases.contains { $0.matches("nonexistent setting") })
    }
}
