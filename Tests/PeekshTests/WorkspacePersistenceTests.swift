import AppKit
import XCTest
import PeekshCore
@testable import Peeksh

@MainActor
final class WorkspacePersistenceTests: XCTestCase {
    private func settings() -> SettingsStore {
        let name = "peeksh-workspace-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return SettingsStore(defaults: defaults)
    }
    private func configuration(directory: String = "/tmp") -> ShellConfiguration {
        ShellConfiguration(shell: "/bin/zsh", home: "/tmp", inheritedEnvironment: ["PATH": "/usr/bin:/bin", "HISTFILE": "/dev/null"], arguments: ["-f"], workingDirectory: directory)
    }
    private func store() throws -> WorkspaceStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("peeksh-workspace-\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return WorkspaceStore(directory: root)
    }
    private func splitKey(_ root: PaneTree) -> String {
        guard case .split(let axis, let first, let second) = root else { return "" }
        return "\(axis.rawValue):\(first.leaves[0]):\(second.leaves[0])"
    }

    func testRelaunchRestoresMetadataAndStableIDsButStartsFreshProcesses() throws {
        _ = NSApplication.shared
        let store = try store()
        let original = TerminalWorkspace(settings: settings(), store: store)
        let first = original.addSession(configuration: configuration())
        original.split(.vertical, configuration: configuration())
        let secondID = original.activeID!
        let firstTabID = original.activeTabID!
        let tree = original.activeTab!.root
        original.renameTab(firstTabID, name: "Project")
        original.saveSplitFraction(0.7, for: splitKey(tree))
        original.addSession(configuration: configuration())
        original.selectTab(firstTabID)
        original.mode = .compact
        original.stopAll()
        let restored = TerminalWorkspace(settings: settings(), store: store)
        defer { restored.stopAll() }
        restored.restoreSavedWorkspace()
        XCTAssertEqual(restored.tabs.count, 2)
        XCTAssertEqual(restored.activeTabID, firstTabID)
        XCTAssertEqual(restored.activeID, secondID)
        XCTAssertEqual(restored.activeTab?.root, tree)
        XCTAssertEqual(restored.activeTab?.customName, "Project")
        XCTAssertEqual(restored.splitFraction(for: splitKey(tree)), 0.7)
        XCTAssertEqual(restored.mode, .compact)
        XCTAssertEqual(restored.session(first.id)?.directory, "/tmp")
        XCTAssertFalse(restored.session(first.id) === first)
        XCTAssertTrue(restored.session(first.id)!.isRunning)
        XCTAssertTrue(restored.session(first.id)!.terminal.process.running)
    }

    func testRestoreMissingDirectoryFallsBackToHomeAndDisabledRestoreKeepsEmptyWorkspace() throws {
        _ = NSApplication.shared
        let store = try store()
        let original = TerminalWorkspace(settings: settings(), store: store)
        let session = original.addSession(configuration: configuration())
        session.hostCurrentDirectoryUpdate(source: session.terminal, directory: URL(fileURLWithPath: "/missing-peeksh-\(UUID())").absoluteString)
        original.stopAll()
        let restored = TerminalWorkspace(settings: settings(), store: store)
        defer { restored.stopAll() }
        restored.restoreSavedWorkspace()
        XCTAssertEqual(restored.active?.directory, FileManager.default.homeDirectoryForCurrentUser.path)
        let disabledSettings = settings()
        disabledSettings.value.restoreWorkspace = false
        let disabled = TerminalWorkspace(settings: disabledSettings, store: store)
        disabled.restoreSavedWorkspace()
        XCTAssertTrue(disabled.sessions.isEmpty)
    }

    func testProfilesCloneIDsAndRatiosWithoutStoppingExistingSessionsAndRenamePreservesSnapshot() async throws {
        _ = NSApplication.shared
        let store = try store()
        let workspace = TerminalWorkspace(settings: settings(), store: store)
        defer { workspace.stopAll() }
        let original = workspace.addSession(configuration: configuration())
        workspace.split(.horizontal, configuration: configuration())
        let oldRoot = workspace.activeTab!.root
        workspace.saveSplitFraction(0.66, for: splitKey(oldRoot))
        let pid = original.terminal.process.shellPid
        original.terminal.send(txt: "sleep 30\n")
        let deadline = Date().addingTimeInterval(5)
        while tcgetpgrp(original.terminal.process.childfd) == pid && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        let foregroundPID = tcgetpgrp(original.terminal.process.childfd)
        XCTAssertGreaterThan(foregroundPID, 0)
        XCTAssertNotEqual(foregroundPID, pid)
        workspace.saveProfile(name: "One")
        let profile = try XCTUnwrap(workspace.profiles.first)
        workspace.saveProfile(name: "Two")
        XCTAssertFalse(workspace.renameProfile(profile.id, name: "Two"))
        XCTAssertTrue(workspace.renameProfile(profile.id, name: "Renamed"))
        XCTAssertEqual(workspace.profiles.first?.id, profile.id)
        XCTAssertEqual(workspace.profiles.first?.snapshot, profile.snapshot)
        workspace.openProfile(profile.id)
        XCTAssertEqual(workspace.tabs.count, 2)
        XCTAssertEqual(workspace.sessions.count, 4)
        XCTAssertEqual(original.terminal.process.shellPid, pid)
        XCTAssertTrue(original.terminal.process.running)
        XCTAssertEqual(tcgetpgrp(original.terminal.process.childfd), foregroundPID)
        XCTAssertEqual(kill(foregroundPID, 0), 0)
        let clonedRoot = workspace.activeTab!.root
        XCTAssertTrue(Set(clonedRoot.leaves).isDisjoint(with: oldRoot.leaves))
        XCTAssertEqual(workspace.splitFraction(for: splitKey(clonedRoot)), 0.66)
        workspace.saveProfile(name: "Renamed")
        XCTAssertEqual(workspace.profiles.count, 2)
        XCTAssertEqual(workspace.profiles.first?.id, profile.id)
        XCTAssertEqual(workspace.profiles.first?.snapshot.tabs.count, 2)
        let reopened = TerminalWorkspace(settings: settings(), store: store)
        XCTAssertEqual(reopened.profiles.map(\.name), ["Renamed", "Two"])
        workspace.deleteProfile(profile.id)
        XCTAssertEqual(workspace.profiles.map(\.name), ["Two"])
    }

    func testTabDuplicationReorderingAndIndexSelectionPreserveProcesses() {
        _ = NSApplication.shared
        let workspace = TerminalWorkspace(settings: settings())
        defer { workspace.stopAll() }
        let original = workspace.addSession(configuration: configuration())
        workspace.split(.vertical, configuration: configuration())
        let firstTab = workspace.activeTabID!
        workspace.renameTab(firstTab, name: "Work")
        let root = workspace.activeTab!.root
        workspace.saveSplitFraction(0.6, for: splitKey(root))
        workspace.duplicateTab(firstTab)
        let secondTab = workspace.activeTabID!
        XCTAssertNotEqual(firstTab, secondTab)
        XCTAssertEqual(workspace.activeTab?.customName, "Work")
        XCTAssertEqual(workspace.activeTab?.root.leaves.count, 2)
        XCTAssertTrue(Set(workspace.activeTab!.root.leaves).isDisjoint(with: root.leaves))
        XCTAssertEqual(workspace.splitFraction(for: splitKey(workspace.activeTab!.root)), 0.6)
        workspace.moveTab(secondTab, before: firstTab)
        XCTAssertEqual(workspace.tabs.map(\.id), [secondTab, firstTab])
        workspace.moveActiveTab(1)
        XCTAssertEqual(workspace.tabs.map(\.id), [firstTab, secondTab])
        workspace.selectTab(at: 0)
        XCTAssertEqual(workspace.activeTabID, firstTab)
        workspace.selectTab(at: 99)
        XCTAssertEqual(workspace.activeTabID, firstTab)
        XCTAssertTrue(original.terminal.process.running)
    }

    func testCompletionCallbackIgnoresPromptAndUsesStartDoneAndNaturalTermination() async {
        _ = NSApplication.shared
        let workspace = TerminalWorkspace(settings: settings())
        defer { workspace.stopAll() }
        let session = workspace.addSession(configuration: configuration())
        var completions: [(UUID, TimeInterval)] = []
        var completionActivities: [TerminalActivity] = []
        workspace.onCommandCompleted = {
            completions.append(($0.id, $1))
            completionActivities.append($0.activity)
        }
        session.terminal.feed(text: "\u{1b}]7777;done;0\u{7}")
        XCTAssertTrue(completions.isEmpty)
        session.terminal.feed(text: "\u{1b}]7777;start\u{7}")
        try? await Task.sleep(nanoseconds: 30_000_000)
        session.terminal.feed(text: "\u{1b}]7777;done;9\u{7}")
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completionActivities, [.failed(9)])
        XCTAssertEqual(completions.first?.0, session.id)
        XCTAssertGreaterThan(completions.first!.1, 0.02)
        session.terminal.feed(text: "\u{1b}]7777;done;0\u{7}")
        XCTAssertEqual(completions.count, 1)
        session.terminal.feed(text: "\u{1b}]7777;start\u{7}")
        session.processTerminated(source: session.terminal, exitCode: 7 << 8)
        XCTAssertEqual(completions.count, 2)
        XCTAssertEqual(session.exitCode, 7)
    }
    func testDirectoryUpdatesPersistImmediatelyAndMetadataExcludesTerminalContent() throws {
        _ = NSApplication.shared
        let store = try store()
        let workspace = TerminalWorkspace(settings: settings(), store: store)
        defer { workspace.stopAll() }
        let session = workspace.addSession(configuration: configuration())
        session.terminal.feed(text: "output-only-marker\u{1b}]0;command-title-only-marker\u{7}")
        session.hostCurrentDirectoryUpdate(source: session.terminal, directory: URL(fileURLWithPath: "/var/tmp").absoluteString)
        let saved = try store.load()
        XCTAssertEqual(saved.workspace?.sessions.first?.directory, "/var/tmp")
        let json = String(data: try JSONEncoder().encode(saved), encoding: .utf8)!
        XCTAssertFalse(json.contains("output-only-marker"))
        XCTAssertFalse(json.contains("command-title-only-marker"))
        XCTAssertFalse(json.contains("environment"))
        XCTAssertFalse(json.contains("arguments"))
        XCTAssertFalse(json.contains("executable"))
    }

    func testExplicitDirectoryWithMetacharactersIsPassedAsDataAndClonedIntoProfile() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("peeksh space ü '#?&\" \(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = TerminalWorkspace(settings: settings())
        defer { workspace.stopAll() }
        let original = workspace.addSession(directory: root.path)
        XCTAssertEqual(original.directory, root.path)
        workspace.saveProfile(name: "Path")
        XCTAssertTrue(workspace.openProfile(workspace.profiles[0].id))
        XCTAssertEqual(workspace.active?.directory, root.path)
        XCTAssertEqual(workspace.profiles[0].snapshot.sessions[0].directory, root.path)
    }

    func testCorruptOrInconsistentMetadataCannotCreateUnlinkedSessions() throws {
        _ = NSApplication.shared
        let name = "peeksh-corruption-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WorkspaceStore(defaults: defaults)
        defaults.set(Data("not json".utf8), forKey: "workspace")
        let corrupt = TerminalWorkspace(settings: settings(), store: store)
        corrupt.restoreSavedWorkspace()
        XCTAssertTrue(corrupt.sessions.isEmpty)
        let id = UUID()
        let invalid = WorkspaceSnapshot(sessions: [.init(id: id, directory: "/tmp")],
            tabs: [.init(id: UUID(), root: .leaf(UUID()), customName: nil, selectedPaneID: nil)],
            activeTabID: nil, splitFractions: [:], mode: .compact)
        try store.save(SavedWorkspace(workspace: invalid))
        let inconsistent = TerminalWorkspace(settings: settings(), store: store)
        inconsistent.restoreSavedWorkspace()
        XCTAssertTrue(inconsistent.sessions.isEmpty)
        XCTAssertTrue(inconsistent.tabs.isEmpty)
    }

    func testDisablingRestoreRemovesSavedArrangementButKeepsProfiles() throws {
        _ = NSApplication.shared
        let store = try store()
        let settings = settings()
        let workspace = TerminalWorkspace(settings: settings, store: store)
        defer { workspace.stopAll() }
        workspace.addSession(configuration: configuration())
        workspace.saveProfile(name: "Keep")
        settings.value.restoreWorkspace = false
        workspace.applyPreferences()
        XCTAssertNil(try store.load().workspace)
        XCTAssertEqual(try store.load().profiles.map(\.name), ["Keep"])
    }

    func testWriteFailurePublishesRecoverableError() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("peeksh-write-error-\(UUID())")
        try Data().write(to: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = TerminalWorkspace(settings: settings(), store: WorkspaceStore(directory: root))
        defer { workspace.stopAll() }
        workspace.addSession(configuration: configuration())
        XCTAssertNotNil(workspace.persistenceError)
        XCTAssertFalse(workspace.saveProfile(name: "Retry"))
        try FileManager.default.removeItem(at: root)
        workspace.saveWorkspace()
        XCTAssertNil(workspace.persistenceError)
    }

    func testRealIntegratedZshCdPersistsAndClonesPercentEncodedDirectory() async throws {
        _ = NSApplication.shared
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("peeksh-cwd-\(UUID())")
        let destination = home.appendingPathComponent("space ü # % ? ' \" & ; $ ` end")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let rc = "PROMPT='cwd-test> '\nprecmd() { return 0 }\n"
        try rc.write(to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        let store = try store()
        let workspace = TerminalWorkspace(settings: settings(), store: store)
        defer { workspace.stopAll() }
        let config = ShellConfiguration(shell: "/bin/zsh", home: home.path,
            inheritedEnvironment: ["PATH": "/usr/bin:/bin", "HISTFILE": "/dev/null", "LC_ALL": "en_US.UTF-8",
                                   "PEEKSH_TEST_DEST": destination.path],
            workingDirectory: home.path, integrationDirectory: ShellIntegration.zshDirectory)
        let session = workspace.addSession(configuration: config)
        let promptDeadline = Date().addingTimeInterval(5)
        while session.activity != .ready && Date() < promptDeadline { try? await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertEqual(session.activity, .ready)
        session.terminal.send(txt: "builtin cd -- \"$PEEKSH_TEST_DEST\"; builtin false\n")
        let cdDeadline = Date().addingTimeInterval(3)
        while (session.directory != destination.path || session.activity != .failed(1)) && Date() < cdDeadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(session.directory, destination.path, "The real precmd hook must report a safely encoded working directory")
        XCTAssertEqual(session.activity, .failed(1), "Directory reporting must preserve the command exit status")
        XCTAssertEqual(try store.load().workspace?.sessions.first?.directory, destination.path)
        XCTAssertTrue(workspace.saveProfile(name: "Actual cwd"))
        workspace.duplicateTab(workspace.activeTabID!)
        XCTAssertEqual(workspace.active?.directory, destination.path)
        XCTAssertTrue(workspace.openProfile(workspace.profiles[0].id))
        XCTAssertEqual(workspace.active?.directory, destination.path)
        workspace.stopAll()
        let restored = TerminalWorkspace(settings: settings(), store: store)
        defer { restored.stopAll() }
        restored.restoreSavedWorkspace()
        XCTAssertEqual(restored.sessions.count, 3)
        XCTAssertTrue(restored.sessions.allSatisfy { $0.directory == destination.path })
        XCTAssertTrue(restored.sessions.allSatisfy { $0.terminal.process.running })
        XCTAssertEqual(try String(contentsOf: home.appendingPathComponent(".zshrc"), encoding: .utf8), rc)
    }

    func testSelectingSiblingInSameZoomedTabRevealsItsLivePane() {
        _ = NSApplication.shared
        let workspace = TerminalWorkspace(settings: settings())
        defer { workspace.stopAll() }
        let first = workspace.addSession(configuration: configuration())
        workspace.split(.vertical, configuration: configuration())
        let second = workspace.active!
        workspace.select(first.id)
        workspace.toggleZoom()
        XCTAssertEqual(workspace.zoomedPaneID, first.id)
        workspace.selectTab(workspace.activeTabID!)
        workspace.select(second.id)
        XCTAssertEqual(workspace.activeID, second.id)
        XCTAssertEqual(workspace.zoomedPaneID, second.id)
        XCTAssertTrue(first.terminal.process.running)
        XCTAssertTrue(second.terminal.process.running)
    }

    func testMoveTabToFinalIndexSupportsBothEndPositionsWithoutChangingSelectionOrProcesses() {
        _ = NSApplication.shared
        let workspace = TerminalWorkspace(settings: settings())
        defer { workspace.stopAll() }
        let first = workspace.addSession(configuration: configuration())
        let firstTab = workspace.activeTabID!
        let second = workspace.addSession(configuration: configuration())
        let secondTab = workspace.activeTabID!
        let pids = workspace.sessions.map { $0.terminal.process.shellPid }
        workspace.moveTab(firstTab, to: 1)
        XCTAssertEqual(workspace.tabs.map(\.id), [secondTab, firstTab])
        XCTAssertEqual(workspace.activeTabID, secondTab)
        XCTAssertEqual(workspace.activeID, second.id)
        workspace.moveTab(firstTab, to: 0)
        XCTAssertEqual(workspace.tabs.map(\.id), [firstTab, secondTab])
        XCTAssertEqual(workspace.activeTabID, secondTab)
        XCTAssertEqual(workspace.sessions.map { $0.terminal.process.shellPid }, pids)
        XCTAssertTrue(first.terminal.process.running)
        XCTAssertTrue(second.terminal.process.running)
    }

}
