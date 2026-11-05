import AppKit
import Combine
import Darwin
import SwiftTerm
import PeekshCore

final class TerminalSession: NSObject, LocalProcessTerminalViewDelegate {
    let id: UUID
    let terminal: LocalProcessTerminalView
    private(set) var title: String
    private(set) var directory: String
    private(set) var isRunning = false
    private(set) var exitCode: Int32?
    private(set) var activity: TerminalActivity = .unavailable
    var onUpdate: (() -> Void)?
    var onCommandCompleted: ((TimeInterval) -> Void)?
    var onDirectoryChange: (() -> Void)?
    private var commandStartedAt: TimeInterval?
    private var stopped = false
    private var lastPreferences: AppPreferences?
    private let shellExecutable: String

    var compactTitle: String { TerminalLabel.directoryName(directory) }
    var titleHelp: String { "\(directory)\n\(title)" }

    var hasRunningCommand: Bool {
        guard isRunning, terminal.process.running else { return false }
        if activity == .running { return true }
        let shellPID = terminal.process.shellPid
        guard shellPID > 0 else { return false }
        var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let pathLength = path.withUnsafeMutableBytes { proc_pidpath(shellPID, $0.baseAddress, UInt32($0.count)) }
        guard pathLength > 0 else { return true }
        if URL(fileURLWithPath: String(cString: path)).resolvingSymlinksInPath().path != shellExecutable {
            return true // exec can replace the shell without changing its PID or process group.
        }
        let foreground = tcgetpgrp(terminal.process.childfd)
        if foreground > 0 && foreground != shellPID { return true }
        // A prompt can be ready while background jobs still belong to its shell.
        var children = [pid_t](repeating: 0, count: 16)
        return children.withUnsafeMutableBytes {
            proc_listchildpids(shellPID, $0.baseAddress, Int32($0.count)) > 0
        }
    }

    init(configuration: ShellConfiguration, preferences: AppPreferences, id: UUID = UUID()) {
        self.id = id
        shellExecutable = URL(fileURLWithPath: configuration.executable).resolvingSymlinksInPath().path
        title = URL(fileURLWithPath: configuration.executable).lastPathComponent
        directory = configuration.workingDirectory
        terminal = LocalProcessTerminalView(
            frame: CGRect(x: 0, y: 0, width: 720, height: 360),
            font: preferences.font.font(size: preferences.fontSize, customName: preferences.customFontName),
            options: TerminalOptions(cursorStyle: preferences.terminalCursorStyle, scrollback: preferences.scrollback)
        )
        super.init()
        // SwiftTerm's standalone overlay scroller stays visible even without history.
        // Hide the indicator while retaining the terminal's wheel/trackpad scrolling.
        terminal.subviews.compactMap { $0 as? NSScroller }.forEach { $0.isHidden = true }
        terminal.processDelegate = self
        terminal.setAccessibilityLabel("Terminal session")
        terminal.terminal.registerOscHandler(code: ShellIntegration.statusCode) { [weak self] data in
            guard let self, self.isRunning, !self.stopped,
                  let report = String(bytes: data, encoding: .utf8),
                  let activity = TerminalActivity(shellReport: report) else { return }
            let changed = self.activity != activity
            self.activity = activity
            if activity == .running {
                if self.commandStartedAt == nil { self.commandStartedAt = ProcessInfo.processInfo.systemUptime }
            } else {
                self.completeCommand()
            }
            if changed { self.onUpdate?() }
        }
        apply(preferences)
        isRunning = true
        terminal.startProcess(executable: configuration.executable, args: configuration.arguments,
                              environment: configuration.environment, currentDirectory: configuration.workingDirectory)
    }

    private func completeCommand() {
        guard let start = commandStartedAt else { return }
        commandStartedAt = nil
        onCommandCompleted?(max(0, ProcessInfo.processInfo.systemUptime - start))
    }

    func apply(_ preferences: AppPreferences) {
        let font = preferences.font.font(size: preferences.fontSize, customName: preferences.customFontName)
        if terminal.font.fontName != font.fontName || terminal.font.pointSize != font.pointSize { terminal.font = font }
        if lastPreferences?.theme != preferences.theme {
            terminal.nativeBackgroundColor = preferences.theme.background
            terminal.nativeForegroundColor = preferences.theme.foreground
            terminal.caretColor = preferences.theme.accent
            terminal.selectedTextBackgroundColor = preferences.theme.selection
            terminal.selectedTextForegroundColor = preferences.theme.foreground
            terminal.installColors(preferences.theme.ansi.map {
                Color(red: UInt16(($0 >> 16) & 255) * 257, green: UInt16(($0 >> 8) & 255) * 257, blue: UInt16($0 & 255) * 257)
            })
        }
        terminal.optionAsMetaKey = preferences.optionAsMeta
        if lastPreferences?.scrollback != preferences.scrollback { terminal.terminal.changeScrollback(preferences.scrollback) }
        if lastPreferences?.cursor != preferences.cursor || lastPreferences?.cursorBlinks != preferences.cursorBlinks {
            terminal.terminal.setCursorStyle(preferences.terminalCursorStyle)
        }
        lastPreferences = preferences
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        terminal.processDelegate = nil
        onUpdate = nil
        onCommandCompleted = nil
        onDirectoryChange = nil
        commandStartedAt = nil
        if terminal.process.running {
            let shellPID = terminal.process.shellPid
            let foreground = tcgetpgrp(terminal.process.childfd)
            if foreground > 0 && foreground != getpgrp() { kill(-foreground, SIGHUP) }
            if shellPID > 0 { kill(shellPID, SIGHUP) }
            terminal.terminate()
            // terminate() cancels SwiftTerm's exit monitor, so reap our child off the UI thread.
            if shellPID > 0 {
                DispatchQueue.global(qos: .utility).async {
                    var status: Int32 = 0
                    var result: pid_t
                    repeat { result = waitpid(shellPID, &status, 0) } while result == -1 && errno == EINTR
                }
            }
        }
        isRunning = false
        activity = .ended
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) { onUpdate?() }
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        self.title = String(title.prefix(4096))
        onUpdate?()
    }
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        if let directory, let url = URL(string: directory), url.isFileURL, self.directory != url.path {
            self.directory = url.path
            onDirectoryChange?()
        }
        onUpdate?()
    }
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard !stopped else { return }
        isRunning = false
        // SwiftTerm's macOS process delegate returns waitpid's packed status.
        self.exitCode = exitCode.map { status in
            let signal = status & 0x7f
            return signal == 0 ? (status >> 8) & 0xff : 128 + signal
        }
        activity = self.exitCode.map { $0 == 0 ? .ended : .failed($0) } ?? .ended
        completeCommand()
        onUpdate?()
    }
}

private extension AppPreferences {
    var terminalCursorStyle: CursorStyle {
        switch (cursor, cursorBlinks) {
        case (.bar, false): return .steadyBar
        case (.bar, true): return .blinkBar
        case (.block, false): return .steadyBlock
        case (.block, true): return .blinkBlock
        case (.underline, false): return .steadyUnderline
        case (.underline, true): return .blinkUnderline
        }
    }
}

struct TerminalTab: Identifiable {
    let id: UUID
    var root: PaneTree
    var customName: String?

    init(id: UUID = UUID(), root: PaneTree, customName: String? = nil) {
        self.id = id
        self.root = root
        self.customName = customName
    }
}

final class TerminalWorkspace: ObservableObject {
    @Published private(set) var sessions: [TerminalSession] = []
    @Published private(set) var tabs: [TerminalTab] = []
    @Published private(set) var activeTabID: UUID?
    @Published private(set) var activeID: UUID? {
        didSet {
            if let activeID, let tab = activeTab, tab.root.leaves.contains(activeID) {
                selectedPaneIDs[tab.id] = activeID
            }
        }
    }
    @Published private(set) var zoomedPaneID: UUID?
    @Published var mode: PanelMode {
        didSet { settings.lastWindowMode = mode; saveWorkspace() }
    }
    @Published private(set) var profiles: [WorkspaceProfile] = []
    @Published private(set) var persistenceError: String?
    let settings: SettingsStore
    private let store: WorkspaceStore?
    private var savedWorkspace: WorkspaceSnapshot?
    private var restoring = false
    private var stopped = false
    var onCommandCompleted: ((TerminalSession, TimeInterval) -> Void)?
    var onHide: (() -> Void)?
    var onShow: (() -> Void)?
    var onSettings: (() -> Void)?
    var onAbout: (() -> Void)?
    var onConfirmTermination: (([TerminalSession]) -> Bool)?
    var preventsAutoHide = false
    private var splitFractions: [String: Double] = [:]
    private var selectedPaneIDs: [UUID: UUID] = [:]

    init(settings: SettingsStore, store: WorkspaceStore? = nil) {
        self.settings = settings
        self.store = store
        mode = settings.lastWindowMode
        if let saved = try? store?.load() {
            savedWorkspace = saved.workspace
            profiles = saved.profiles.filter { $0.snapshot.isValid }
        }
    }
    var active: TerminalSession? { sessions.first { $0.id == activeID } }
    var activeTab: TerminalTab? { tabs.first { $0.id == activeTabID } }
    var activity: TerminalActivity { TerminalActivity.combined(sessions.map(\.activity)) }

    func activity(for tab: TerminalTab) -> TerminalActivity {
        TerminalActivity.combined(tab.root.leaves.compactMap { session($0)?.activity })
    }

    func session(_ id: UUID) -> TerminalSession? { sessions.first { $0.id == id } }
    func splitFraction(for key: String) -> Double { splitFractions[key] ?? 0.5 }
    func saveSplitFraction(_ fraction: Double, for key: String) {
        guard fraction.isFinite else { return }
        splitFractions[key] = fraction
        saveWorkspace()
    }

    private func makeSession(directory: String? = nil, configuration: ShellConfiguration? = nil, id: UUID = UUID()) -> TerminalSession {
        let config: ShellConfiguration
        if let configuration { config = configuration }
        else {
            let shell = getpwuid(getuid()).flatMap { $0.pointee.pw_shell }.map { String(cString: $0) } ?? "/bin/zsh"
            config = ShellConfiguration(shell: shell, home: FileManager.default.homeDirectoryForCurrentUser.path,
                                        inheritedEnvironment: ProcessInfo.processInfo.environment,
                                        workingDirectory: usableDirectory(directory ?? (settings.value.inheritDirectory ? active?.directory : nil)),
                                        integrationDirectory: ShellIntegration.zshDirectory)
        }
        let session = TerminalSession(configuration: config, preferences: settings.value, id: id)
        session.onUpdate = { [weak self] in
            // SwiftTerm can report a resize during SwiftUI's layout pass.
            DispatchQueue.main.async { [weak self] in self?.objectWillChange.send() }
        }
        session.onDirectoryChange = { [weak self] in self?.saveWorkspace() }
        session.onCommandCompleted = { [weak self, weak session] duration in
            guard let self, let session else { return }
            self.onCommandCompleted?(session, duration)
        }
        sessions.append(session)
        return session
    }

    @discardableResult
    func addSession(directory: String? = nil, configuration: ShellConfiguration? = nil) -> TerminalSession {
        let session = makeSession(directory: directory, configuration: configuration)
        let tab = TerminalTab(root: .leaf(session.id))
        tabs.append(tab)
        activeTabID = tab.id
        activeID = session.id
        zoomedPaneID = nil
        focusActive()
        saveWorkspace()
        return session
    }

    func select(_ id: UUID) {
        guard activeTab?.root.leaves.contains(id) == true else { return }
        activeID = id
        if zoomedPaneID != nil { zoomedPaneID = id }
        focusActive()
        saveWorkspace()
    }
    func synchronizeFocus(with responder: NSResponder?) {
        if let session = sessions.first(where: { $0.terminal === responder }),
           activeTab?.root.leaves.contains(session.id) == true, activeID != session.id {
            activeID = session.id
            saveWorkspace()
        }
    }
    func selectTab(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        guard activeTabID != id else { focusActive(); return }
        activeTabID = id
        activeID = selectedPane(in: tab)
        zoomedPaneID = nil
        focusActive()
        saveWorkspace()
    }
    private func selectedPane(in tab: TerminalTab) -> UUID? {
        if let id = selectedPaneIDs[tab.id], tab.root.leaves.contains(id) { return id }
        return tab.root.leaves.first
    }
    func split(_ axis: SplitAxis, configuration: ShellConfiguration? = nil) {
        guard let activeID, let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let newSession = makeSession(configuration: configuration)
        tabs[index].root = tabs[index].root.splitting(activeID, axis: axis, newPane: newSession.id)
        self.activeID = newSession.id
        zoomedPaneID = nil
        focusActive()
        saveWorkspace()
    }
    func focusActive() {
        DispatchQueue.main.async { [weak self] in
            guard let terminal = self?.active?.terminal else { return }
            terminal.window?.makeFirstResponder(terminal)
        }
    }
    func close(_ id: UUID) {
        guard let session = session(id), confirmTermination(of: [session]) else { return }
        removeSession(id)
    }

    private func removeSession(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        guard let tabIndex = tabs.firstIndex(where: { $0.root.leaves.contains(id) }) else { return }
        let tabID = tabs[tabIndex].id
        if let root = tabs[tabIndex].root.removing(id) {
            tabs[tabIndex].root = root
            if activeID == id { activeID = root.leaves.first }
        } else {
            tabs.remove(at: tabIndex)
            selectedPaneIDs.removeValue(forKey: tabID)
            if activeTabID == tabID {
                activeTabID = tabs.isEmpty ? nil : tabs[min(tabIndex, tabs.count - 1)].id
                activeID = activeTab.flatMap { selectedPane(in: $0) }
            }
        }
        sessions[index].stop()
        sessions.remove(at: index)
        if let zoomedPaneID, activeTab?.root.leaves.contains(zoomedPaneID) != true {
            self.zoomedPaneID = nil
        }
        if sessions.isEmpty { onHide?() }
        focusActive()
        saveWorkspace()
    }
    func restartActive() {
        guard let id = activeID, let tabIndex = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let session = makeSession()
        tabs[tabIndex].root = tabs[tabIndex].root.splitting(id, axis: .horizontal, newPane: session.id).removing(id)!
        if let old = sessions.firstIndex(where: { $0.id == id }) {
            sessions[old].stop()
            sessions.remove(at: old)
        }
        activeID = session.id
        zoomedPaneID = nil
        focusActive()
        saveWorkspace()
    }
    func cycleTab(_ direction: Int) {
        guard !tabs.isEmpty, let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        selectTab(tabs[(index + direction + tabs.count) % tabs.count].id)
    }
    func cyclePane(_ direction: Int) {
        guard let leaves = activeTab?.root.leaves, let index = leaves.firstIndex(of: activeID ?? UUID()) else { return }
        let id = leaves[(index + direction + leaves.count) % leaves.count]
        if zoomedPaneID != nil { zoomedPaneID = id }
        select(id)
    }
    func toggleZoom() {
        guard let count = activeTab?.root.leaves.count, count > 1 else { return }
        zoomedPaneID = zoomedPaneID == nil ? activeID : nil
        focusActive()
    }
    func closeTab(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        let candidates = tab.root.leaves.compactMap { session($0) }
        guard confirmTermination(of: candidates) else { return }
        tab.root.leaves.forEach { removeSession($0) }
    }
    func renameTab(_ id: UUID, name: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].customName = name.isEmpty ? nil : name
        saveWorkspace()
    }
    func applyPreferences() {
        if mode != settings.lastWindowMode { mode = settings.lastWindowMode }
        sessions.forEach { $0.apply(settings.value) }
        saveWorkspace()
        objectWillChange.send()
    }
    func stopAll() {
        saveWorkspace()
        stopped = true
        sessions.forEach { $0.stop() }
    }

    private func usableDirectory(_ directory: String?) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard let directory, directory.hasPrefix("/") else { return home }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory) && isDirectory.boolValue
            ? directory : home
    }

    private func snapshot(for selectedTabs: [TerminalTab]? = nil) -> WorkspaceSnapshot {
        let includedTabs = selectedTabs ?? tabs
        let includedIDs = Set(includedTabs.flatMap { $0.root.leaves })
        var keys = Set<String>()
        func collectKeys(_ node: PaneTree) {
            if case .split(let axis, let first, let second) = node {
                keys.insert("\(axis.rawValue):\(first.leaves[0]):\(second.leaves[0])")
                collectKeys(first)
                collectKeys(second)
            }
        }
        includedTabs.forEach { collectKeys($0.root) }
        return WorkspaceSnapshot(
            sessions: sessions.filter { includedIDs.contains($0.id) }.map { .init(id: $0.id, directory: $0.directory) },
            tabs: includedTabs.map { .init(id: $0.id, root: $0.root, customName: $0.customName, selectedPaneID: selectedPane(in: $0)) },
            activeTabID: includedTabs.contains(where: { $0.id == activeTabID }) ? activeTabID : includedTabs.first?.id,
            splitFractions: splitFractions.filter { keys.contains($0.key) }, mode: mode)
    }

    func saveWorkspace() {
        guard !restoring, !stopped, let store else { return }
        savedWorkspace = settings.value.restoreWorkspace ? snapshot() : nil
        do {
            try store.save(SavedWorkspace(workspace: savedWorkspace, profiles: profiles))
            persistenceError = nil
        } catch {
            persistenceError = "Workspace could not be saved: \(error.localizedDescription)"
        }
    }

    func restoreSavedWorkspace() {
        guard sessions.isEmpty, settings.value.restoreWorkspace, let savedWorkspace, savedWorkspace.isValid else { return }
        restoring = true
        append(savedWorkspace)
        mode = savedWorkspace.mode
        restoring = false
        saveWorkspace()
    }

    private func append(_ snapshot: WorkspaceSnapshot) {
        guard snapshot.isValid else { return }
        for saved in snapshot.sessions { _ = makeSession(directory: saved.directory, id: saved.id) }
        for tab in snapshot.tabs {
            tabs.append(TerminalTab(id: tab.id, root: tab.root, customName: tab.customName))
            if let pane = tab.selectedPaneID, tab.root.leaves.contains(pane) { selectedPaneIDs[tab.id] = pane }
        }
        splitFractions.merge(snapshot.splitFractions) { _, new in new }
        if let tabID = snapshot.activeTabID, snapshot.tabs.contains(where: { $0.id == tabID }) {
            activeTabID = tabID
        } else if let tabID = snapshot.tabs.first?.id {
            activeTabID = tabID
        }
        activeID = activeTab.flatMap { selectedPane(in: $0) }
        zoomedPaneID = nil
        focusActive()
    }

    @discardableResult
    func saveProfile(name: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !tabs.isEmpty else { return false }
        if let index = profiles.firstIndex(where: { $0.name == name }) {
            profiles[index].snapshot = snapshot()
        } else {
            profiles.append(WorkspaceProfile(id: UUID(), name: name, snapshot: snapshot()))
        }
        saveWorkspace()
        return persistenceError == nil
    }

    @discardableResult
    func renameProfile(_ id: UUID, name: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = profiles.firstIndex(where: { $0.id == id }),
              !profiles.contains(where: { $0.id != id && $0.name == name }) else { return false }
        profiles[index].name = name
        saveWorkspace()
        return persistenceError == nil
    }

    @discardableResult
    func openProfile(_ id: UUID) -> Bool {
        guard let profile = profiles.first(where: { $0.id == id }), profile.snapshot.isValid else { return false }
        append(profile.snapshot.cloned())
        saveWorkspace()
        return true
    }

    func deleteProfile(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        saveWorkspace()
    }

    func duplicateTab(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        let copied = snapshot(for: [tab]).cloned()
        append(copied)
        if let newID = copied.tabs.first?.id, let index = tabs.firstIndex(where: { $0.id == id }),
           let copiedIndex = tabs.firstIndex(where: { $0.id == newID }) {
            let duplicate = tabs.remove(at: copiedIndex)
            tabs.insert(duplicate, at: index + 1)
        }
        saveWorkspace()
    }

    /// Moves to the desired final zero-based position, including the last slot.
    func moveTab(_ id: UUID, to index: Int) {
        guard tabs.indices.contains(index), let original = tabs.firstIndex(where: { $0.id == id }),
              original != index else { return }
        let tab = tabs.remove(at: original)
        tabs.insert(tab, at: index)
        saveWorkspace()
    }

    func moveTab(_ id: UUID, before targetID: UUID) {
        guard id != targetID, let index = tabs.firstIndex(where: { $0.id == id }),
              tabs.contains(where: { $0.id == targetID }) else { return }
        let tab = tabs.remove(at: index)
        let target = tabs.firstIndex(where: { $0.id == targetID })!
        tabs.insert(tab, at: target)
        saveWorkspace()
    }

    func moveActiveTab(_ offset: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let target = max(0, min(tabs.count - 1, index + offset))
        guard index != target else { return }
        let tab = tabs.remove(at: index)
        tabs.insert(tab, at: target)
        saveWorkspace()
    }

    /// Zero-based index, matching Swift collections and the keyboard menu's number minus one.
    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectTab(tabs[index].id)
    }

    func confirmTermination(of candidates: [TerminalSession]) -> Bool {
        let busy = candidates.filter(\.hasRunningCommand)
        guard !busy.isEmpty else { return true }
        let wasPreventingAutoHide = preventsAutoHide
        preventsAutoHide = true
        defer {
            preventsAutoHide = wasPreventingAutoHide
            focusActive()
        }
        return onConfirmTermination?(busy) ?? false
    }
}
