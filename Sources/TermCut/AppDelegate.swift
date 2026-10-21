import AppKit
import Combine
import SwiftUI
import TermCutCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    let settings = SettingsStore()
    let hotKeys = HotKeyManager()
    private var workspace: TerminalWorkspace!
    private var terminalPanel: TerminalPanelController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: UtilityWindowController?
    private var aboutWindow: UtilityWindowController?
    private let activityDot = MenuBarActivityDot()
    private var activityObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        workspace = TerminalWorkspace(settings: settings)
        terminalPanel = TerminalPanelController(workspace: workspace, settings: settings)
        workspace.onHide = { [weak self] in self?.terminalPanel.hide() }
        workspace.onModeChange = { [weak self] in self?.terminalPanel.show($0) }
        workspace.onSettings = { [weak self] in self?.showSettings() }
        workspace.onAbout = { [weak self] in self?.showAbout() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "term-cut")
            button.image?.isTemplate = true
            button.toolTip = "term-cut — click to toggle, right-click for options"
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
            DispatchQueue.main.async { [weak self] in self?.updateActivityIndicator() }
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
        if CommandLine.arguments.contains("--settings") { showSettings() }
        else if CommandLine.arguments.contains("--about") { showAbout() }
        else if CommandLine.arguments.contains("--dropdown") { terminalPanel.show(.dropDown) }
        else if CommandLine.arguments.contains("--compact") { terminalPanel.show(.compact) }
        else if settings.value.showOnLaunch { terminalPanel.show(settings.value.menuBarMode) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        terminalPanel.show(settings.value.menuBarMode)
        return false
    }
    func applicationWillTerminate(_ notification: Notification) { workspace?.stopAll() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func updateActivityIndicator() {
        let activity = workspace.activity
        activityDot.activity = activity
        let description = workspace.sessions.isEmpty ? "No sessions" : activity.description
        statusItem.button?.toolTip = "term-cut — \(description)\nClick to toggle, right-click for options"
        statusItem.button?.setAccessibilityLabel("term-cut — \(description)")
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            add("Show Compact Terminal", action: #selector(showCompact), to: menu)
            add("Show Drop-down Terminal", action: #selector(showDropDown), to: menu)
            menu.addItem(.separator())
            add("Settings…", action: #selector(showSettings), key: ",", to: menu)
            add("About term-cut", action: #selector(showAbout), to: menu)
            menu.addItem(.separator())
            add("Quit term-cut", action: #selector(quit), key: "q", to: menu)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else { terminalPanel.toggle(settings.value.menuBarMode) }
    }

    @objc private func showCompact() { terminalPanel.show(.compact) }
    @objc private func showDropDown() { terminalPanel.show(.dropDown) }
    @objc private func newTab() { workspace.addSession(); terminalPanel.show(workspace.mode) }
    @objc private func splitRight() { workspace.split(.horizontal) }
    @objc private func splitDown() { workspace.split(.vertical) }
    @objc private func closePane() {
        if let keyWindow = NSApp.keyWindow, keyWindow !== terminalPanel.panel { keyWindow.performClose(nil) }
        else if let id = workspace.activeID { workspace.close(id) }
    }
    @objc private func closeTab() { if let id = workspace.activeTabID { workspace.closeTab(id) } }
    @objc private func nextTab() { workspace.cycleTab(1) }
    @objc private func previousTab() { workspace.cycleTab(-1) }
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
            settingsWindow = UtilityWindowController(title: "Settings — term-cut", size: NSSize(width: 620, height: 680),
                                                     content: SettingsView(settings: settings, hotKeys: hotKeys), autosave: "term-cut-settings")
        }
        settingsWindow?.present()
    }
    @objc func showAbout() {
        terminalPanel?.hide()
        if aboutWindow == nil {
            aboutWindow = UtilityWindowController(title: "About term-cut", size: NSSize(width: 390, height: 440),
                                                     content: AboutContent().frame(maxWidth: .infinity, maxHeight: .infinity).padding(24),
                                                     autosave: "term-cut-about")
        }
        aboutWindow?.present()
    }

    private func buildMainMenu() {
        let main = NSMenu()
        let app = NSMenu(title: "term-cut")
        add("About term-cut", action: #selector(showAbout), to: app)
        add("Settings…", action: #selector(showSettings), key: ",", to: app)
        app.addItem(.separator())
        add("Hide term-cut", action: #selector(hideWindows), key: "h", to: app)
        add("Quit term-cut", action: #selector(quit), key: "q", to: app)
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
        add("Compact Window", action: #selector(showCompact), to: view)
        add("Drop-down Window", action: #selector(showDropDown), to: view)
        view.addItem(.separator())
        add("Larger Text", action: #selector(increaseText), key: "+", to: view)
        add("Smaller Text", action: #selector(decreaseText), key: "-", to: view)
        add("Reset Text Size", action: #selector(resetText), key: "0", to: view)
        for menu in [app, terminal, edit, view] {
            let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
            item.submenu = menu
            main.addItem(item)
        }
        NSApp.mainMenu = main
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
            #selector(clearScrollback), #selector(increaseText), #selector(decreaseText), #selector(resetText)]
        if menuItem.action == #selector(focusPane) {
            return NSApp.keyWindow === terminalPanel?.panel && (workspace?.activeTab?.root.leaves.count ?? 0) > 1
        }
        if let action = menuItem.action, terminalActions.contains(action) {
            return NSApp.keyWindow === terminalPanel?.panel && workspace?.active != nil
        }
        return true
    }
}
