import AppKit
import Combine
import SwiftUI
import PeekshCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSMenuDelegate {
    let settings = SettingsStore()
    let hotKeys = HotKeyManager()
    let notifications = CommandCompletionNotifier()
    private var workspace: TerminalWorkspace!
    private var terminalPanel: TerminalPanelController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: UtilityWindowController?
    private var aboutWindow: UtilityWindowController?
    private let activityDot = MenuBarActivityDot()
    private var activityObserver: AnyCancellable?
    private var profileMenu: NSMenu?
    private var pendingOpenRequests: [TerminalOpenRequest] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let dataDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.berkinduz.peeksh", isDirectory: true)
        workspace = TerminalWorkspace(settings: settings, store: WorkspaceStore(directory: dataDirectory))
        terminalPanel = TerminalPanelController(workspace: workspace, settings: settings,
                                                placementStore: WindowPlacementStore(defaults: .standard))
        workspace.onHide = { [weak self] in self?.terminalPanel.hide() }
        workspace.onShow = { [weak self] in self?.terminalPanel.show() }
        workspace.onSettings = { [weak self] in self?.showSettings() }
        workspace.onAbout = { [weak self] in self?.showAbout() }
        workspace.onCommandCompleted = { [weak self] session, duration in
            guard let self else { return }
            let preferences = self.settings.value
            self.notifications.commandCompleted(session, duration: duration, preferences: preferences)
        }
        notifications.isTerminalVisible = { [weak self] in self?.terminalPanel.isPresented ?? false }
        notifications.onOpenSession = { [weak self] id in
            guard let self, let tab = self.workspace.tabs.first(where: { $0.root.leaves.contains(id) }) else { return }
            self.workspace.selectTab(tab.id)
            self.workspace.select(id)
            self.terminalPanel.show(self.workspace.mode)
        }
        workspace.onConfirmTermination = { sessions in
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Stop running commands?"
            alert.informativeText = sessions.count == 1
                ? "This session has a running command or background job. Closing it will stop its processes."
                : "\(sessions.count) sessions have running commands or background jobs. Closing them will stop their processes."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Stop and Close")
            return alert.runModal() == .alertSecondButtonReturn
        }
        workspace.restoreSavedWorkspace()
        NSApp.servicesProvider = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = MenuBarIcon.makeImage()
            button.image?.isTemplate = true
            button.toolTip = "Peeksh — click to toggle, right-click for options"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            activityDot.translatesAutoresizingMaskIntoConstraints = false
            activityDot.setAccessibilityElement(false)
            button.addSubview(activityDot)
            NSLayoutConstraint.activate([
                activityDot.widthAnchor.constraint(equalToConstant: 6),
                activityDot.heightAnchor.constraint(equalToConstant: 6),
                activityDot.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -1),
                activityDot.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: 2)
            ])
        }
        activityObserver = workspace.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.updateActivityIndicator()
            }
        }
        updateActivityIndicator()
        terminalPanel.statusAnchor = { [weak self] in
            guard let button = self?.statusItem.button, let window = button.window else { return nil }
            return window.convertToScreen(button.convert(button.bounds, to: nil))
        }
        hotKeys.onShortcut = { [weak self] in self?.terminalPanel.toggle($0) }
        settings.onChange = { [weak self] in
            guard let self else { return }
            self.workspace.applyPreferences()
            self.terminalPanel.applyPreferences()
            self.hotKeys.update(self.settings.value)
        }
        hotKeys.update(settings.value)
        buildMainMenu()
        notifications.refreshAuthorization()
        var launch = TerminalLaunchOptions()
        do {
            launch = try TerminalLaunchOptions(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch { showOpenError(error.localizedDescription) }
        if let mode = launch.mode { workspace.mode = mode }
        if let request = launch.request { pendingOpenRequests.append(request) }
        let requests = pendingOpenRequests
        pendingOpenRequests.removeAll()
        requests.forEach(handleOpenRequest)
        if launch.utility == .settings { showSettings() }
        else if launch.utility == .about { showAbout() }
        else if requests.isEmpty && launch.mode != nil {
            terminalPanel.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
    func applicationWillTerminate(_ notification: Notification) { terminalPanel?.shutdown(); workspace?.stopAll() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let workspace else { return .terminateNow }
        return workspace.confirmTermination(of: workspace.sessions) ? .terminateNow : .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func updateActivityIndicator() {
        let activity = workspace.activity
        activityDot.activity = activity
        let description = workspace.sessions.isEmpty ? "No sessions" : activity.description
        statusItem.button?.toolTip = "Peeksh — \(description)\nClick to toggle, right-click for options"
        statusItem.button?.setAccessibilityLabel("Peeksh — \(description)")
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            add("Show Terminal", action: #selector(showTerminal), to: menu)
            menu.addItem(.separator())
            add("Settings…", action: #selector(showSettings), key: ",", to: menu)
            add("About Peeksh", action: #selector(showAbout), to: menu)
            menu.addItem(.separator())
            add("Quit Peeksh", action: #selector(quit), key: "q", to: menu)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else { terminalPanel.toggle() }
    }

    @objc private func showTerminal() { terminalPanel.show() }
    @objc private func newTab() { workspace.addSession(); terminalPanel.show() }
    @objc private func splitRight() { workspace.split(.horizontal) }
    @objc private func splitDown() { workspace.split(.vertical) }
    @objc private func closePane() {
        if let keyWindow = NSApp.keyWindow, keyWindow !== terminalPanel.panel { keyWindow.performClose(nil) }
        else if let id = workspace.activeID { workspace.close(id) }
    }
    @objc private func closeTab() { if let id = workspace.activeTabID { workspace.closeTab(id) } }
    @objc private func nextTab() { workspace.cycleTab(1) }
    @objc private func previousTab() { workspace.cycleTab(-1) }
    @objc private func duplicateTab() { if let id = workspace.activeTabID { workspace.duplicateTab(id) } }
    @objc private func moveTabLeft() { workspace.moveActiveTab(-1) }
    @objc private func moveTabRight() { workspace.moveActiveTab(1) }
    @objc private func selectTabNumber(_ sender: NSMenuItem) { workspace.selectTab(at: sender.tag) }
    @objc private func saveCurrentProfile() { ProfileActions.saveCurrent(workspace) }
    @objc private func openProfile(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let id = UUID(uuidString: value) else { return }
        if workspace.openProfile(id) { terminalPanel.show() }
    }
    @objc private func nextPane() { workspace.cyclePane(1) }
    @objc private func previousPane() { workspace.cyclePane(-1) }
    @objc private func focusPane() { workspace.toggleZoom() }
    @objc private func clearScrollback() { workspace.active?.terminal.clearScrollback(); workspace.focusActive() }
    @objc private func hideTerminal() { terminalPanel.hide() }
    @objc private func hideWindows() {
        terminalPanel.hide()
        settingsWindow?.window?.orderOut(nil)
        aboutWindow?.window?.orderOut(nil)
    }
    @objc private func increaseText() { settings.value.fontSize = min(24, settings.value.fontSize + 1) }
    @objc private func decreaseText() { settings.value.fontSize = max(10, settings.value.fontSize - 1) }
    @objc private func resetText() { settings.value.fontSize = 13 }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func showSettings() {
        terminalPanel?.hide()
        if settingsWindow == nil {
            settingsWindow = UtilityWindowController(title: "Settings — Peeksh", size: NSSize(width: 620, height: 680),
                                                     content: SettingsView(settings: settings, hotKeys: hotKeys, workspace: workspace,
                                                                           notifications: notifications), autosave: "peeksh-settings")
        }
        settingsWindow?.present()
    }
    @objc func showAbout() {
        terminalPanel?.hide()
        if aboutWindow == nil {
            aboutWindow = UtilityWindowController(title: "About Peeksh", size: NSSize(width: 390, height: 440),
                                                     content: AboutContent().frame(maxWidth: .infinity, maxHeight: .infinity).padding(24),
                                                     autosave: "peeksh-about")
        }
        aboutWindow?.present()
    }

    private func buildMainMenu() {
        let main = NSMenu()
        let app = NSMenu(title: "Peeksh")
        add("About Peeksh", action: #selector(showAbout), to: app)
        add("Settings…", action: #selector(showSettings), key: ",", to: app)
        let services = NSMenu(title: "Services")
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = services
        app.addItem(servicesItem)
        NSApp.servicesMenu = services
        app.addItem(.separator())
        add("Hide Peeksh", action: #selector(hideWindows), key: "h", to: app)
        add("Quit Peeksh", action: #selector(quit), key: "q", to: app)
        let terminal = NSMenu(title: "Terminal")
        add("New Tab", action: #selector(newTab), key: "t", to: terminal)
        add("Close Pane", action: #selector(closePane), key: "w", to: terminal)
        add("Close Tab", action: #selector(closeTab), key: "w", modifiers: [.command, .shift], to: terminal)
        terminal.addItem(.separator())
        add("Split Right", action: #selector(splitRight), key: "d", to: terminal)
        add("Split Down", action: #selector(splitDown), key: "d", modifiers: [.command, .shift], to: terminal)
        add("Focus Pane", action: #selector(focusPane), key: "\r", modifiers: [.command, .shift], to: terminal)
        terminal.addItem(.separator())
        add("Next Pane", action: #selector(nextPane), key: "]", to: terminal)
        add("Previous Pane", action: #selector(previousPane), key: "[", to: terminal)
        add("Next Tab", action: #selector(nextTab), key: "\t", modifiers: [.control], to: terminal)
        add("Previous Tab", action: #selector(previousTab), key: "\t", modifiers: [.control, .shift], to: terminal)
        add("Duplicate Tab", action: #selector(duplicateTab), to: terminal)
        add("Move Tab Left", action: #selector(moveTabLeft), to: terminal)
        add("Move Tab Right", action: #selector(moveTabRight), to: terminal)
        let selectTab = NSMenu(title: "Select Tab")
        for index in 0..<9 {
            let item = add("Tab \(index + 1)", action: #selector(selectTabNumber(_:)), key: "\(index + 1)", to: selectTab)
            item.tag = index
        }
        let selectItem = NSMenuItem(title: "Select Tab", action: nil, keyEquivalent: "")
        selectItem.submenu = selectTab
        terminal.addItem(selectItem)
        terminal.addItem(.separator())
        add("Clear Scrollback", action: #selector(clearScrollback), key: "k", to: terminal)
        add("Hide Terminal", action: #selector(hideTerminal), key: "h", modifiers: [.command, .shift], to: terminal)
        let edit = NSMenu(title: "Edit")
        add("Copy", action: #selector(NSText.copy(_:)), key: "c", to: edit, responderChain: true)
        add("Paste", action: #selector(NSText.paste(_:)), key: "v", to: edit, responderChain: true)
        add("Select All", action: #selector(NSResponder.selectAll(_:)), key: "a", to: edit, responderChain: true)
        let find = add("Find…", action: #selector(NSTextView.performFindPanelAction(_:)), key: "f", to: edit, responderChain: true)
        find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        let view = NSMenu(title: "View")
        add("Larger Text", action: #selector(increaseText), key: "+", to: view)
        add("Smaller Text", action: #selector(decreaseText), key: "-", to: view)
        add("Reset Text Size", action: #selector(resetText), key: "0", to: view)
        let profiles = NSMenu(title: "Profiles")
        profiles.delegate = self
        profileMenu = profiles
        for menu in [app, terminal, profiles, edit, view] {
            let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
            item.submenu = menu
            main.addItem(item)
        }
        NSApp.mainMenu = main
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === profileMenu else { return }
        menu.removeAllItems()
        for profile in workspace.profiles {
            let item = add(profile.name, action: #selector(openProfile(_:)), to: menu)
            item.representedObject = profile.id.uuidString
        }
        if !workspace.profiles.isEmpty { menu.addItem(.separator()) }
        add("Save Current Layout…", action: #selector(saveCurrentProfile), to: menu)
        add("Manage Profiles…", action: #selector(showSettings), to: menu)
    }

    @discardableResult
    private func add(_ title: String, action: Selector, key: String = "", modifiers: NSEvent.ModifierFlags = [.command],
                     to menu: NSMenu, target: AnyObject? = nil, responderChain: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = responderChain ? nil : (target ?? self)
        menu.addItem(item)
        return item
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let terminalActions: [Selector] = [#selector(splitRight), #selector(splitDown), #selector(closeTab),
            #selector(nextPane), #selector(previousPane), #selector(nextTab), #selector(previousTab),
            #selector(duplicateTab), #selector(moveTabLeft), #selector(moveTabRight),
            #selector(clearScrollback), #selector(increaseText), #selector(decreaseText), #selector(resetText)]
        if menuItem.action == #selector(selectTabNumber(_:)) {
            return NSApp.keyWindow === terminalPanel?.panel && menuItem.tag < (workspace?.tabs.count ?? 0)
        }
        if menuItem.action == #selector(saveCurrentProfile) { return workspace?.tabs.isEmpty == false }
        if menuItem.action == #selector(focusPane) {
            return NSApp.keyWindow === terminalPanel?.panel && (workspace?.activeTab?.root.leaves.count ?? 0) > 1
        }
        if let action = menuItem.action, terminalActions.contains(action) {
            return NSApp.keyWindow === terminalPanel?.panel && workspace?.active != nil
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            do {
                handleOpenRequest(try url.isFileURL ? .directory(url) : TerminalOpenRequest(url: url))
            } catch { showOpenError(error.localizedDescription) }
        }
    }

    @objc func openInPeeksh(_ pasteboard: NSPasteboard, userData: String?,
                             error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty, urls.allSatisfy(Self.isDirectory) else {
            error.pointee = "Select one or more folders to open in Peeksh." as NSString
            return
        }
        urls.forEach { handleOpenRequest(.directory($0)) }
    }

    private func handleOpenRequest(_ request: TerminalOpenRequest) {
        guard let workspace else { pendingOpenRequests.append(request); return }
        switch request {
        case .directory(let url):
            guard Self.isDirectory(url) else { showOpenError("The folder does not exist: \(url.path)"); return }
            workspace.addSession(directory: url.path)
        case .profile(let name):
            guard let profile = workspace.profiles.first(where: { $0.name == name }), workspace.openProfile(profile.id) else {
                showOpenError("No saved project profile named “\(name)”.")
                return
            }
        }
        terminalPanel.show()
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        return url.isFileURL && FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func showOpenError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Could Not Open in Peeksh"
        alert.informativeText = message
        alert.runModal()
    }
}
