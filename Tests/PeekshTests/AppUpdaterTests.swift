import Foundation
import XCTest
import PeekshCore
@testable import Peeksh

@MainActor
final class AppUpdaterTests: XCTestCase {
    private func release(version: String = "0.3.4") throws -> AppRelease {
        let data = Data("""
        {"tag_name":"v\(version)","assets":[{"name":"Peeksh.dmg","browser_download_url":"https://github.com/berkinduz/peeksh/releases/download/v\(version)/Peeksh.dmg","digest":"sha256:\(String(repeating: "a", count: 64))"}]}
        """.utf8)
        return try XCTUnwrap(AppRelease.available(in: data, installedVersion: "0.3.3"))
    }

    func testBackgroundCheckAnnouncesAvailabilityWithoutDownloadingOrRestarting() async throws {
        let release = try release()
        var downloads = 0
        let updater = AppUpdater(check: { release }, prepare: { _ in downloads += 1; throw URLError(.cancelled) })
        await updater.checkForUpdates(silently: true)
        XCTAssertEqual(updater.availableRelease, release)
        XCTAssertTrue(updater.menuTitle.contains("Update Available"))
        XCTAssertEqual(downloads, 0)
        XCTAssertFalse(updater.isBusy)
    }

    func testOneActionChecksDownloadsAndRequestsRestart() async throws {
        let release = try release()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var checks = 0, downloads = 0, restarts = 0
        let prepared = PreparedAppUpdate(directory: root, application: root.appendingPathComponent("Peeksh.app"),
                                         destination: root.appendingPathComponent("installed.app"), installer: root.appendingPathComponent("installer"))
        let updater = AppUpdater(check: { checks += 1; return release }, prepare: { value in
            XCTAssertEqual(value, release)
            downloads += 1
            return prepared
        })
        updater.onReadyToInstall = { update in
            XCTAssertEqual(update.destination, prepared.destination)
            restarts += 1
        }
        await updater.update()
        XCTAssertEqual(checks, 1)
        XCTAssertEqual(downloads, 1)
        XCTAssertEqual(restarts, 1)
        XCTAssertEqual(updater.status, .restarting)
    }

    func testCurrentVersionDoesNotDownloadOrRestart() async {
        var downloads = 0, restarts = 0
        let updater = AppUpdater(check: { nil }, prepare: { _ in downloads += 1; throw URLError(.cancelled) })
        updater.onReadyToInstall = { _ in restarts += 1 }
        await updater.update()
        XCTAssertEqual(downloads, 0)
        XCTAssertEqual(restarts, 0)
        XCTAssertEqual(updater.status, .upToDate)
    }

    func testExplicitUpdateRefreshesVersionAfterAnAvailabilityCheck() async throws {
        let first = try release(), newest = try release(version: "0.3.5")
        var checks = 0
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let prepared = PreparedAppUpdate(directory: root, application: root.appendingPathComponent("Peeksh.app"),
                                         destination: root.appendingPathComponent("installed.app"), installer: root.appendingPathComponent("installer"))
        let updater = AppUpdater(check: { checks += 1; return checks == 1 ? first : newest }, prepare: { release in
            XCTAssertEqual(release, newest)
            return prepared
        })
        updater.onReadyToInstall = { _ in }
        await updater.checkForUpdates(silently: true)
        XCTAssertEqual(updater.availableRelease, first)
        await updater.update()
        XCTAssertEqual(checks, 2)
        XCTAssertEqual(updater.availableRelease, newest)
    }

    func testBackgroundNetworkFailureKeepsKnownUpdateAndStaysQuiet() async throws {
        let release = try release()
        var fails = false
        let updater = AppUpdater(check: {
            if fails { throw URLError(.notConnectedToInternet) }
            return release
        }, prepare: { _ in throw URLError(.cancelled) })
        await updater.checkForUpdates(silently: true)
        fails = true
        await updater.checkForUpdates(silently: true)
        XCTAssertEqual(updater.availableRelease, release)
        XCTAssertEqual(updater.status, .idle)
    }

    func testFailedDownloadDoesNotRequestQuitAndKeepsTheUpdateAvailable() async throws {
        let release = try release()
        var restarts = 0
        let updater = AppUpdater(check: { release }, prepare: { _ in throw URLError(.badServerResponse) })
        updater.onReadyToInstall = { _ in restarts += 1 }
        await updater.update()
        XCTAssertEqual(restarts, 0)
        XCTAssertEqual(updater.availableRelease, release)
        guard case .failed = updater.status else { return XCTFail("Download failure must be visible") }
    }

    func testCancelledQuitCleansStagingWithoutRequestingAnotherRestart() async throws {
        let release = try release()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let prepared = PreparedAppUpdate(directory: root, application: root.appendingPathComponent("Peeksh.app"),
                                         destination: root.appendingPathComponent("installed.app"), installer: root.appendingPathComponent("installer"))
        let updater = AppUpdater(check: { release }, prepare: { _ in prepared })
        updater.onReadyToInstall = { _ in updater.cancelInstallation() }
        await updater.update()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        XCTAssertEqual(updater.status, .idle)
        XCTAssertEqual(updater.availableRelease, release)
    }
}
