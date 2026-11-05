import Foundation
import XCTest
@testable import PeekshCore

final class UpdateInstallationTests: XCTestCase {
    private func fixture(_ body: (URL, URL, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("peeksh update test \(UUID())").resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let installed = root.appendingPathComponent("Applications/Peeksh.app", isDirectory: true)
        let staged = root.appendingPathComponent("staged/Peeksh.app", isDirectory: true)
        for (url, text) in [(installed, "old"), (staged, "new")] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url.appendingPathComponent("version"))
        }
        try body(root, installed, staged)
    }

    func testReplacesTheBundleThenRelaunchesTheSamePath() throws {
        try fixture { root, installed, staged in
            var launched: URL?
            try UpdateInstallation.install(from: staged, to: installed) { url in
                launched = url
                XCTAssertEqual(try String(contentsOf: url.appendingPathComponent("version")), "new")
            }
            XCTAssertEqual(launched, installed)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: installed.deletingLastPathComponent().path), ["Peeksh.app"])
        }
    }

    func testFailedRelaunchRestoresTheOldBundle() throws {
        struct LaunchFailure: Error {}
        try fixture { root, installed, staged in
            XCTAssertThrowsError(try UpdateInstallation.install(from: staged, to: installed) { _ in throw LaunchFailure() })
            XCTAssertEqual(try String(contentsOf: installed.appendingPathComponent("version")), "old")
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: installed.deletingLastPathComponent().path), ["Peeksh.app"])
        }
    }

    func testHomebrewSymlinkIsPreservedWhileItsTargetIsUpdated() throws {
        try fixture { root, installed, staged in
            let link = root.appendingPathComponent("Linked Peeksh.app")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: installed)
            try UpdateInstallation.install(from: staged, to: link) { url in XCTAssertEqual(url, installed) }
            XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), installed.path)
            XCTAssertEqual(try String(contentsOf: link.appendingPathComponent("version")), "new")
        }
    }

    func testMissingStagedBundleLeavesTheOriginalUntouched() throws {
        try fixture { root, installed, staged in
            var launched = false
            XCTAssertThrowsError(try UpdateInstallation.install(from: root.appendingPathComponent("missing.app"), to: installed) { _ in launched = true })
            XCTAssertFalse(launched)
            XCTAssertEqual(try String(contentsOf: installed.appendingPathComponent("version")), "old")
        }
    }
}
