import XCTest
import PeekshCore
@testable import Peeksh

@MainActor
final class WindowModeTests: XCTestCase {
    func testSingleWindowMigratesBothRetiredLayouts() throws {
        XCTAssertEqual(PanelMode.allCases, [.compact])
        for legacy in ["island", "dropDown"] {
            XCTAssertEqual(PanelMode(savedValue: legacy), .compact)
            XCTAssertEqual(try JSONDecoder().decode(PanelMode.self, from: JSONEncoder().encode(legacy)), .compact)
        }
        XCTAssertEqual(String(data: try JSONEncoder().encode(PanelMode.compact), encoding: .utf8), "\"compact\"")
        XCTAssertNil(PanelMode(savedValue: "unknown"))
        XCTAssertThrowsError(try JSONDecoder().decode(PanelMode.self, from: Data("\"unknown\"".utf8)))
    }

    func testLegacyWorkspaceLayoutsMigrateWithoutDiscardingMetadata() throws {
        for legacy in ["island", "dropDown"] {
            let data = Data("""
            {"sessions":[],"tabs":[],"splitFractions":{},"mode":"\(legacy)"}
            """.utf8)
            let snapshot = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
            XCTAssertEqual(snapshot.mode, .compact)
            XCTAssertTrue(snapshot.isValid)
            XCTAssertFalse(String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self).contains(legacy))
        }
    }

    func testRetiredLastWindowModeOpensSingleWindowWithoutResettingPreferences() throws {
        let suite = "peeksh-mode-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("island", forKey: "lastWindowMode")
        defaults.set(try JSONSerialization.data(withJSONObject: ["theme":"Paper", "compactWidth":920]), forKey: "preferences")
        let settings = SettingsStore(defaults: defaults)
        let workspace = TerminalWorkspace(settings: settings)
        XCTAssertEqual(workspace.mode, .compact)
        XCTAssertEqual(settings.value.theme, .paper)
        XCTAssertEqual(settings.value.compactWidth, 920)
        workspace.mode = .compact
        XCTAssertEqual(defaults.string(forKey: "lastWindowMode"), "compact")
        XCTAssertEqual(TerminalWorkspace(settings: SettingsStore(defaults: defaults)).mode, .compact)
    }
}
