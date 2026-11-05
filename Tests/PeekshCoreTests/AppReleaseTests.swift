import CryptoKit
import Foundation
import XCTest
@testable import PeekshCore

final class AppReleaseTests: XCTestCase {
    private func response(version: String = "0.3.4", digest: String = String(repeating: "a", count: 64),
                          url: String? = nil) -> Data {
        let download = url ?? "https://github.com/berkinduz/peeksh/releases/download/v\(version)/Peeksh.dmg"
        return try! JSONSerialization.data(withJSONObject: [
            "tag_name": "v\(version)",
            "assets": [["name": "Peeksh.dmg", "browser_download_url": download, "digest": "sha256:\(digest)"]]
        ])
    }

    func testFindsNewerStableReleaseAndComparesVersionNumbersNumerically() throws {
        let release = try XCTUnwrap(AppRelease.available(in: response(version: "0.3.10"), installedVersion: "0.3.9"))
        XCTAssertEqual(release.version, "0.3.10")
        XCTAssertEqual(release.sha256, String(repeating: "a", count: 64))
        XCTAssertNil(try AppRelease.available(in: response(), installedVersion: "0.3.4"))
        XCTAssertNil(try AppRelease.available(in: response(), installedVersion: "0.4.0"))
    }

    func testDoesNotAcceptUnverifiedOrUnrelatedDownload() {
        XCTAssertThrowsError(try AppRelease.available(in: response(digest: "invalid"), installedVersion: "0.3.3"))
        XCTAssertThrowsError(try AppRelease.available(in: response(url: "https://example.com/Peeksh.dmg"), installedVersion: "0.3.3"))
        XCTAssertThrowsError(try AppRelease.available(in: Data("{}".utf8), installedVersion: "0.3.3"))
    }

    func testDownloadedBytesMustMatchThePublishedDigest() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let bytes = Data("published DMG bytes".utf8)
        try bytes.write(to: file)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let release = try XCTUnwrap(AppRelease.available(in: response(digest: digest), installedVersion: "0.3.3"))
        XCTAssertNoThrow(try release.verifyDownload(at: file))
        try Data("different bytes".utf8).write(to: file)
        XCTAssertThrowsError(try release.verifyDownload(at: file))
    }
}
