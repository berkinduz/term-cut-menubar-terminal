import CryptoKit
import Foundation
import XCTest
import PeekshCore
@testable import Peeksh

final class UpdateDownloadTests: XCTestCase {
    private func release(_ bytes: Data, version: String) throws -> AppRelease {
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let data = try JSONSerialization.data(withJSONObject: ["tag_name": "v\(version)", "assets": [[
            "name": "Peeksh.dmg", "browser_download_url": "https://github.com/berkinduz/peeksh/releases/download/v\(version)/Peeksh.dmg",
            "digest": "sha256:\(digest)"
        ]]])
        return try XCTUnwrap(AppRelease.available(in: data, installedVersion: "0.0.0"))
    }

    private func installedFixture(in root: URL) throws -> URL {
        let app = root.appendingPathComponent("Installed Peeksh.app", isDirectory: true)
        let helpers = app.appendingPathComponent("Contents/Helpers", isDirectory: true)
        try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        let helper = helpers.appendingPathComponent("PeekshUpdateInstaller")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: helper)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        try Data("original".utf8).write(to: app.appendingPathComponent("original"))
        return app
    }

    func testInvalidArchiveDoesNotChangeTheInstalledApplication() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("peeksh-download-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let application = try installedFixture(in: root)
        let bytes = Data("not a disk image".utf8)
        let release = try release(bytes, version: "0.3.4")
        let download = root.appendingPathComponent("download.dmg")
        try bytes.write(to: download)
        var fetched = false
        do {
            _ = try await UpdateDownloader.prepare(release, bundleURL: application) { url in
                fetched = true
                XCTAssertEqual(url, release.downloadURL)
                return (download, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            XCTFail("An invalid disk image must not prepare an installation")
        } catch { XCTAssertEqual(error.localizedDescription, AppUpdateError.invalidApplication.localizedDescription) }
        XCTAssertTrue(fetched)
        XCTAssertEqual(try String(contentsOf: application.appendingPathComponent("original")), "original")
    }

    func testPublishedDMGCanBeVerifiedMountedAndStagedWithoutInstalling() async throws {
        guard let fixture = ProcessInfo.processInfo.environment["PEEKSH_UPDATE_INTEGRATION_DMG"] else {
            throw XCTSkip("Supply the verified published DMG for the artifact integration check")
        }
        let bytes = try Data(contentsOf: URL(fileURLWithPath: fixture))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("peeksh-download-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let application = try installedFixture(in: root)
        let release = try release(bytes, version: "0.3.3")
        let download = root.appendingPathComponent("download.dmg")
        try bytes.write(to: download)
        let prepared = try await UpdateDownloader.prepare(release, bundleURL: application) { url in
            (download, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        defer { prepared.cleanUp() }
        XCTAssertEqual(Bundle(url: prepared.application)?.bundleIdentifier, "com.berkinduz.peeksh")
        XCTAssertEqual(Bundle(url: prepared.application)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, "0.3.3")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: prepared.installer.path))
        XCTAssertEqual(try String(contentsOf: application.appendingPathComponent("original")), "original")
    }
}
