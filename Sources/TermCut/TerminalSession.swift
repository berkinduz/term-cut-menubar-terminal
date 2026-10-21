import AppKit
import Combine
import SwiftTerm
import TermCutCore

final class TerminalSession: NSObject, LocalProcessTerminalViewDelegate {
    let id = UUID()
    let terminal: LocalProcessTerminalView
    private(set) var title: String
    private(set) var directory: String
    private(set) var isRunning = false
    private(set) var exitCode: Int32?
    var onUpdate: (() -> Void)?
    private var stopped = false
    private var lastPreferences: AppPreferences?

    init(configuration: ShellConfiguration, preferences: AppPreferences) {
        title = URL(fileURLWithPath: configuration.executable).lastPathComponent
        directory = configuration.workingDirectory
        terminal = LocalProcessTerminalView(
            frame: CGRect(x: 0, y: 0, width: 720, height: 360),
            font: preferences.font.font(size: preferences.fontSize, customName: preferences.customFontName),
            options: TerminalOptions(cursorStyle: preferences.terminalCursorStyle, scrollback: preferences.scrollback)
        )
        super.init()
        terminal.processDelegate = self
        terminal.setAccessibilityLabel("Terminal session")
        apply(preferences)
        isRunning = true
        terminal.startProcess(executable: configuration.executable, args: configuration.arguments,
                              environment: configuration.environment, currentDirectory: configuration.workingDirectory)
    }

    func apply(_ preferences: AppPreferences) {
        let font = preferences.font.font(size: preferences.fontSize, customName: preferences.customFontName)
        if terminal.font.fontName != font.fontName || terminal.font.pointSize != font.pointSize { terminal.font = font }
        if lastPreferences?.theme != preferences.theme {
            terminal.nativeBackgroundColor = preferences.theme.background
            terminal.nativeForegroundColor = preferences.theme.foreground
            terminal.caretColor = preferences.theme.accent
            terminal.selectedTextBackgroundColor = preferences.theme.accent.withAlphaComponent(0.3)
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
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) { onUpdate?() }
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        self.title = String(title.prefix(100))
        onUpdate?()
    }
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        if let directory, let url = URL(string: directory), url.isFileURL { self.directory = url.path }
        onUpdate?()
    }
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard !stopped else { return }
        isRunning = false
        self.exitCode = exitCode
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
    let id = UUID()
    var root: PaneTree
    var customName: String?
}

final class TerminalWorkspace: ObservableObject {
    @Published private(set) var sessions: [TerminalSession] = []
    @Published private(set) var tabs: [TerminalTab] = []
    @Published private(set) var activeTabID: UUID?
    @Published private(set) var activeID: UUID?
    @Published private(set) var zoomedPaneID: UUID?
    @Published var mode: PanelMode = .compact
    let settings: SettingsStore
    var onHide: (() -> Void)?
    var onSettings: (() -> Void)?
    var onAbout: (() -> Void)?
    var preventsAutoHide = false
    private var splitFractions: [String: Double] = [:]

    init(settings: SettingsStore) { self.settings = settings }
    var active: TerminalSession? { sessions.first { $0.id == activeID } }
    var activeTab: TerminalTab? { tabs.first { $0.id == activeTabID } }

    func session(_ id: UUID) -> TerminalSession? { sessions.first { $0.id == id } }
    func splitFraction(for key: String) -> Double { splitFractions[key] ?? 0.5 }
    func saveSplitFraction(_ fraction: Double, for key: String) { splitFractions[key] = fraction }

    private func makeSession(configuration: ShellConfiguration? = nil) -> TerminalSession {
        let config: ShellConfiguration
        if let configuration { config = configuration }
        else {
            let shell = getpwuid(getuid()).flatMap { $0.pointee.pw_shell }.map { String(cString: $0) } ?? "/bin/zsh"
            config = ShellConfiguration(shell: shell, home: FileManager.default.homeDirectoryForCurrentUser.path,
                                        inheritedEnvironment: ProcessInfo.processInfo.environment,
                                        workingDirectory: settings.value.inheritDirectory ? active?.directory : nil)
        }
        let session = TerminalSession(configuration: config, preferences: settings.value)
        session.onUpdate = { [weak self] in self?.objectWillChange.send() }
        sessions.append(session)
        return session
    }

    @discardableResult
    func addSession(configuration: ShellConfiguration? = nil) -> TerminalSession {
        let session = makeSession(configuration: configuration)
        let tab = TerminalTab(root: .leaf(session.id))
        tabs.append(tab)
        activeTabID = tab.id
        activeID = session.id
        zoomedPaneID = nil
        focusActive()
        return session
    }

    func select(_ id: UUID) { activeID = id; focusActive() }
    func synchronizeFocus(with responder: NSResponder?) {
        if let session = sessions.first(where: { $0.terminal === responder }), activeID != session.id { activeID = session.id }
    }
    func selectTab(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        activeTabID = id
        activeID = tab.root.leaves.first
        zoomedPaneID = nil
        focusActive()
    }
    func split(_ axis: SplitAxis, configuration: ShellConfiguration? = nil) {
        guard let activeID, let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let newSession = makeSession(configuration: configuration)
        tabs[index].root = tabs[index].root.splitting(activeID, axis: axis, newPane: newSession.id)
        self.activeID = newSession.id
        zoomedPaneID = nil
        focusActive()
    }
    func focusActive() {
        DispatchQueue.main.async { [weak self] in
            guard let terminal = self?.active?.terminal else { return }
            terminal.window?.makeFirstResponder(terminal)
        }
    }
    func close(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        guard let tabIndex = tabs.firstIndex(where: { $0.root.leaves.contains(id) }) else { return }
        let tabID = tabs[tabIndex].id
        if let root = tabs[tabIndex].root.removing(id) {
            tabs[tabIndex].root = root
            if activeID == id { activeID = root.leaves.first }
        } else {
            tabs.remove(at: tabIndex)
            if activeTabID == tabID {
                activeTabID = tabs.isEmpty ? nil : tabs[min(tabIndex, tabs.count - 1)].id
                activeID = activeTab?.root.leaves.first
            }
        }
        sessions[index].stop()
        sessions.remove(at: index)
        zoomedPaneID = nil
        if sessions.isEmpty { onHide?() }
        focusActive()
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
        tab.root.leaves.forEach { close($0) }
    }
    func renameTab(_ id: UUID, name: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].customName = name.isEmpty ? nil : name
    }
    func applyPreferences() {
        sessions.forEach { $0.apply(settings.value) }
        objectWillChange.send()
    }
    func stopAll() { sessions.forEach { $0.stop() } }
}
