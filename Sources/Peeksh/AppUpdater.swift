import AppKit
import Combine
import Foundation
import PeekshCore

struct PreparedAppUpdate {
    let directory: URL
    let application: URL
    let destination: URL
    let installer: URL

    func launchInstaller(parentPID: Int32) throws {
        let process = Process()
        process.executableURL = installer
        process.arguments = [String(parentPID), application.path, destination.path, directory.path]
        try process.run()
    }

    func cleanUp() { try? FileManager.default.removeItem(at: directory) }
}

enum UpdateDownloader {
    static func latest() async throws -> AppRelease? {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            throw AppUpdateError.invalidApplication
        }
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/berkinduz/peeksh/releases/latest")!,
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Peeksh", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AppUpdateError.requestFailed }
        return try AppRelease.available(in: data, installedVersion: version)
    }

    static func prepare(_ release: AppRelease, bundleURL: URL = Bundle.main.bundleURL,
                        download: (URL) async throws -> (URL, URLResponse) = { try await URLSession.shared.download(from: $0) }) async throws -> PreparedAppUpdate {
        let manager = FileManager.default
        let bundle = bundleURL
        guard bundle.pathExtension == "app" else { throw AppUpdateError.invalidApplication }
        let destination = bundle.resolvingSymlinksInPath()
        guard manager.isWritableFile(atPath: destination.deletingLastPathComponent().path) else {
            throw AppUpdateError.notWritable
        }
        let helper = bundle.appendingPathComponent("Contents/Helpers/PeekshUpdateInstaller")
        guard manager.isExecutableFile(atPath: helper.path) else { throw AppUpdateError.installerMissing }
        let directory = manager.temporaryDirectory.appendingPathComponent("Peeksh-update-\(UUID())")
        try manager.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let mount = directory.appendingPathComponent("mount")
        var mounted = false
        var prepared = false
        defer {
            if mounted { try? run("/usr/bin/hdiutil", ["detach", mount.path]) }
            if !prepared { try? manager.removeItem(at: directory) }
        }
        let (downloadedFile, response) = try await download(release.downloadURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AppUpdateError.requestFailed }
        let dmg = directory.appendingPathComponent("Peeksh.dmg")
        try manager.moveItem(at: downloadedFile, to: dmg)
        try release.verifyDownload(at: dmg)
        try manager.createDirectory(at: mount, withIntermediateDirectories: false)
        try run("/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-mountpoint", mount.path, dmg.path])
        mounted = true
        let source = mount.appendingPathComponent("Peeksh.app")
        guard let candidate = Bundle(url: source), candidate.bundleIdentifier == "com.berkinduz.peeksh",
              candidate.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == release.version else {
            throw AppUpdateError.invalidApplication
        }
        let application = directory.appendingPathComponent("Peeksh.app")
        try run("/usr/bin/ditto", [source.path, application.path])
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", application.path])
        try run("/usr/bin/hdiutil", ["detach", mount.path])
        mounted = false
        let installer = directory.appendingPathComponent("PeekshUpdateInstaller")
        try manager.copyItem(at: helper, to: installer)
        prepared = true
        return PreparedAppUpdate(directory: directory, application: application, destination: destination, installer: installer)
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw AppUpdateError.invalidApplication }
    }
}

@MainActor
final class AppUpdater: ObservableObject {
    enum Status: Equatable { case idle, checking, downloading, restarting, upToDate, failed(String) }
    @Published private(set) var availableRelease: AppRelease?
    @Published private(set) var status: Status = .idle
    var onReadyToInstall: ((PreparedAppUpdate) throws -> Void)?
    private let check: () async throws -> AppRelease?
    private let prepare: (AppRelease) async throws -> PreparedAppUpdate
    private var preparedUpdate: PreparedAppUpdate?
    private var automaticChecks: Task<Void, Never>?

    init(check: @escaping () async throws -> AppRelease? = UpdateDownloader.latest,
         prepare: @escaping (AppRelease) async throws -> PreparedAppUpdate = { try await UpdateDownloader.prepare($0) }) {
        self.check = check
        self.prepare = prepare
    }

    deinit { automaticChecks?.cancel() }

    var isBusy: Bool { status == .checking || status == .downloading || status == .restarting }
    var menuTitle: String {
        availableRelease == nil ? "Check, Update & Restart…" : "Update Available — Install and Restart"
    }
    var buttonTitle: String {
        switch status {
        case .checking: return "Checking…"
        case .downloading: return "Downloading…"
        case .restarting: return "Restarting…"
        default: return availableRelease == nil ? "Check, Update & Restart" : "Update & Restart"
        }
    }

    func startAutomaticChecks() {
        automaticChecks = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                await self?.checkForUpdates(silently: true)
                do { try await Task.sleep(nanoseconds: 6 * 60 * 60 * 1_000_000_000) }
                catch { return }
            }
        }
    }

    func checkForUpdates(silently: Bool) async {
        guard !isBusy else { return }
        status = .checking
        do {
            availableRelease = try await check()
            status = silently || availableRelease != nil ? .idle : .upToDate
        } catch { status = silently ? .idle : .failed(error.localizedDescription) }
    }

    func update() async {
        guard !isBusy else { return }
        status = .checking
        do {
            availableRelease = try await check()
            guard let release = availableRelease else { status = .upToDate; return }
            status = .downloading
            let update = try await prepare(release)
            preparedUpdate = update
            status = .restarting
            guard let onReadyToInstall else { throw AppUpdateError.installerMissing }
            try onReadyToInstall(update)
        } catch { installationFailed(error) }
    }

    func cancelInstallation() {
        preparedUpdate?.cleanUp()
        preparedUpdate = nil
        status = .idle
    }

    func installationFailed(_ error: Error) {
        preparedUpdate?.cleanUp()
        preparedUpdate = nil
        status = .failed(error.localizedDescription)
    }
}
