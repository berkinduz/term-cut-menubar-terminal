import AppKit
import Carbon
import ServiceManagement
import SwiftUI
import PeekshCore
import UserNotifications

final class LoginItemStore: ObservableObject {
    @Published private(set) var enabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var message: String?
    func refresh() { enabled = SMAppService.mainApp.status == .enabled }
    func setEnabled(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refresh()
            message = SMAppService.mainApp.status == .requiresApproval
                ? "Allow Peeksh in System Settings → General → Login Items." : nil
        } catch {
            refresh()
            message = "Could not update login items. Move Peeksh to Applications and try again."
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var hotKeys: HotKeyManager
    @ObservedObject var workspace: TerminalWorkspace
    @ObservedObject var notifications: CommandCompletionNotifier
    @StateObject private var login = LoginItemStore()
    @State private var search = ""
    @State private var screenChoices: [ScreenChoice] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().interpolation(.high).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Make it yours.").font(.system(size: 21, weight: .semibold, design: .rounded))
                    Text("Small details. A better place to work.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(.horizontal, 26).padding(.top, 20).padding(.bottom, 18)
            TextField("Search settings", text: $search)
                .textFieldStyle(.roundedBorder).padding(.horizontal, 26).padding(.bottom, 12)
                .accessibilityLabel("Search settings")

            Form {
                if !SettingsSection.allCases.contains(where: { $0.matches(search) }) {
                    Section {
                        VStack(spacing: 8) {
                            Text("No matching settings").font(.headline)
                            Text("Try a different setting name.").foregroundStyle(.secondary)
                            Button("Clear Search") { search = "" }
                        }.frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                }
                if SettingsSection.general.matches(search) {
                    Section("General") {
                        Toggle("Keep visible when switching apps", isOn: $settings.value.keepVisible)
                        Toggle("Launch at login", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
                        Toggle("Restore workspace on launch", isOn: $settings.value.restoreWorkspace)
                        Text("Restores tabs, folders, and split panes in new shells. Running commands end when you quit.")
                            .font(.caption).foregroundStyle(.secondary)
                        if let message = login.message {
                            Text(message).font(.caption).foregroundStyle(.secondary)
                            Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                        }
                        Text("Closing the panel keeps your sessions running. Quit Peeksh to end them.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if SettingsSection.appearance.matches(search) {
                    Section("Appearance") {
                        Picker("Terminal theme", selection: $settings.value.theme) {
                            ForEach(TerminalTheme.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Font", selection: $settings.value.font) {
                            ForEach(TerminalFont.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if settings.value.font == .custom {
                            Picker("Installed font", selection: $settings.value.customFontName) {
                                ForEach(FontCatalog.monospacedFonts, id: \.self) { name in
                                    Text(NSFont(name: name, size: 13)?.displayName ?? name).tag(name)
                                }
                            }
                        }
                        numberSlider("Text size", value: $settings.value.fontSize, range: 10...24, label: "\(Int(settings.value.fontSize)) pt")
                        numberSlider("Terminal padding", value: $settings.value.terminalPadding, range: 4...24, label: "\(Int(settings.value.terminalPadding)) pt")
                        terminalPreview
                        Toggle("Translucent window bars", isOn: $settings.value.glassEnabled)
                        Toggle("Animate window transitions", isOn: $settings.value.animationsEnabled)
                        Toggle("Dim inactive panes", isOn: $settings.value.dimInactivePanes)
                        Toggle("Show status bar", isOn: $settings.value.showStatusBar)
                        Text("Window bars use a blurred, translucent background. Motion and transparency follow your accessibility settings.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if SettingsSection.windows.matches(search) {
                    Section("Windows") {
                        Picker("Open on display", selection: $settings.value.screenPreference) {
                            Text("Automatic").tag(ScreenPreference.automatic)
                            Text("Display Under Pointer").tag(ScreenPreference.pointer)
                            Text("Main Display").tag(ScreenPreference.main)
                            Text("Choose a Display").tag(ScreenPreference.fixed)
                        }
                        if settings.value.screenPreference == .fixed {
                            Picker("Preferred display", selection: $settings.value.preferredScreenID) {
                                Text("Main Display Until Selected").tag("")
                                ForEach(screenChoices) { Text($0.name).tag($0.id) }
                                if !settings.value.preferredScreenID.isEmpty,
                                   !screenChoices.contains(where: { $0.id == settings.value.preferredScreenID }) {
                                    Text("Disconnected Display").tag(settings.value.preferredScreenID)
                                }
                            }
                        }
                        Toggle("Remember window position", isOn: $settings.value.rememberWindowPosition)
                        numberSlider("Window width", value: $settings.value.compactWidth, range: 520...1200, step: 10,
                                     label: "\(Int(settings.value.compactWidth)) pt")
                        numberSlider("Window height", value: $settings.value.compactHeight, range: 300...850, step: 10,
                                     label: "\(Int(settings.value.compactHeight)) pt")
                        Text("You can also drag the window edges and pane dividers to resize them.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if SettingsSection.terminal.matches(search) {
                    Section("Terminal") {
                        Picker("Cursor shape", selection: $settings.value.cursor) {
                            ForEach(TerminalCursor.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Toggle("Blink cursor", isOn: $settings.value.cursorBlinks)
                        Picker("Scrollback history", selection: $settings.value.scrollback) {
                            Text("5,000 lines").tag(5000)
                            Text("10,000 lines").tag(10000)
                            Text("25,000 lines").tag(25000)
                            Text("50,000 lines").tag(50000)
                        }
                        Toggle("Use Option as Meta", isOn: $settings.value.optionAsMeta)
                        Toggle("New sessions inherit the current directory", isOn: $settings.value.inheritDirectory)
                        Text("Uses your macOS login shell and its normal configuration. Directory inheritance works when your shell reports its working directory using OSC 7.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if SettingsSection.profiles.matches(search) { profileSettings }
                if SettingsSection.notifications.matches(search) { notificationSettings }

                if SettingsSection.keyboardShortcuts.matches(search) {
                    Section("Keyboard Shortcuts") {
                        Toggle("Enable global shortcuts", isOn: $settings.value.shortcutsEnabled)
                        HStack {
                            Text("Toggle terminal"); Spacer()
                            ShortcutRecorder(shortcut: $settings.value.compactShortcut)
                                .frame(width: 170, height: 27).disabled(!settings.value.shortcutsEnabled)
                        }
                        if let error = hotKeys.error { Text(error).font(.caption).foregroundStyle(.orange) }
                        Text("Click a shortcut to record a new combination. Press Escape to cancel. Global shortcuts work without Accessibility permission.")
                            .font(.caption).foregroundStyle(.secondary)
                        shortcutRow("New tab", "⌘T")
                        shortcutRow("Select tab", "⌘1–9")
                        shortcutRow("Split right / down", "⌘D / ⇧⌘D")
                        shortcutRow("Next / previous pane", "⌘] / ⌘[")
                        shortcutRow("Focus pane", "⇧⌘Return")
                        shortcutRow("Find in terminal", "⌘F")
                        shortcutRow("Close pane", "⌘W")
                        shortcutRow("Hide terminal", "⇧⌘H")
                    }
                }

                if SettingsSection.defaults.matches(search) {
                    Section {
                        HStack {
                            Text("Your sessions stay open when settings change.").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Restore Defaults") { settings.reset() }.controlSize(.small)
                        }
                    }
                }
                if SettingsSection.about.matches(search) {
                    Section("About Peeksh") {
                        AboutContent(compact: true).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                }
            }
            .formStyle(.grouped).scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.teal)
        .onAppear { login.refresh(); notifications.refreshAuthorization(); screenChoices = ScreenPlacement.choices }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            login.refresh(); notifications.refreshAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screenChoices = ScreenPlacement.choices
        }
    }

    private var profileSettings: some View {
        Section("Project Profiles") {
            Text("Opening a profile adds new tabs and keeps your running sessions.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(workspace.profiles) { profile in
                HStack {
                    Text(profile.name).lineLimit(1)
                    Spacer()
                    Button("Open") {
                        if workspace.openProfile(profile.id) { workspace.onShow?() }
                    }
                    Button("Rename") { ProfileActions.rename(profile.id, name: profile.name, workspace: workspace) }
                    Button("Delete", role: .destructive) { workspace.deleteProfile(profile.id) }
                }
            }
            Button("Save Current Layout…") { ProfileActions.saveCurrent(workspace) }.disabled(workspace.tabs.isEmpty)
            if let error = workspace.persistenceError { Text(error).font(.caption).foregroundStyle(.red) }
        }
    }

    private var notificationSettings: some View {
        Section("Notifications") {
            Toggle("Notify when commands finish", isOn: Binding(get: { settings.value.commandNotificationsEnabled }, set: {
                settings.value.commandNotificationsEnabled = $0
                notifications.setEnabled($0)
            }))
            numberSlider("Minimum command duration", value: $settings.value.notificationMinimumDuration,
                         range: 5...300, step: 5, label: "\(Int(settings.value.notificationMinimumDuration))s")
                .disabled(!settings.value.commandNotificationsEnabled)
            Text("Notifications appear while the terminal is hidden. Command tracking supports your top-level zsh shell.")
                .font(.caption).foregroundStyle(.secondary)
            if settings.value.commandNotificationsEnabled {
                if notifications.authorizationStatus == .notDetermined {
                    Button("Allow System Notifications") { notifications.setEnabled(true) }
                }
                if let message = notifications.permissionMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func shortcutRow(_ name: String, _ keys: String) -> some View {
        HStack { Text(name).foregroundStyle(.secondary); Spacer(); Text(keys).font(.system(.body, design: .monospaced)) }
    }
    private func numberSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1, label valueLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(label); Spacer(); Text(valueLabel).foregroundStyle(.secondary).monospacedDigit() }
            Slider(value: value, in: range, step: step).accessibilityLabel(label)
        }.padding(.vertical, 3)
    }
    private var terminalPreview: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("PREVIEW").font(.system(size: 9, weight: .medium)).foregroundStyle(Color(settings.value.theme.secondary))
            HStack(spacing: 8) {
                Text("❯").foregroundStyle(Color(settings.value.theme.accent))
                Text("echo \"Room to focus.\"")
            }
            Text("Room to focus.").foregroundStyle(Color(settings.value.theme.secondary))
        }
        .font(Font(settings.value.font.font(size: settings.value.fontSize, customName: settings.value.customFontName)))
        .foregroundStyle(Color(settings.value.theme.foreground))
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Color(settings.value.theme.background), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: GlobalShortcut
    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.setAccessibilityLabel("Record global shortcut")
        return button
    }
    func updateNSView(_ button: RecorderButton, context: Context) {
        button.shortcut = shortcut
        button.onRecord = { shortcut = $0 }
        if !button.recording { button.title = shortcut.label }
    }
}

private final class RecorderButton: NSButton {
    var shortcut = GlobalShortcut.compact
    var onRecord: ((GlobalShortcut) -> Void)?
    private(set) var recording = false
    override var acceptsFirstResponder: Bool { true }
    init() {
        super.init(frame: .zero)
        target = self
        action = #selector(beginRecording)
        font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc private func beginRecording() {
        recording = true
        title = "Press shortcut…"
        window?.makeFirstResponder(self)
    }
    override func resignFirstResponder() -> Bool {
        recording = false
        title = shortcut.label
        return super.resignFirstResponder()
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }
        return super.performKeyEquivalent(with: event)
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == UInt16(kVK_Escape) {
            recording = false; title = shortcut.label; return
        }
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !flags.intersection([.command, .control, .option]).isEmpty else {
            title = "Use ⌘, ⌃ or ⌥"; return
        }
        var modifiers: UInt32 = 0
        for (flag, carbon) in [(NSEvent.ModifierFlags.command, cmdKey), (.control, controlKey), (.option, optionKey), (.shift, shiftKey)] {
            if flags.contains(flag) { modifiers |= UInt32(carbon) }
        }
        let names: [UInt16: String] = [49: "Space", 36: "Return", 48: "Tab", 51: "⌫", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        let key = names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        let newShortcut = GlobalShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, key: key)
        recording = false
        shortcut = newShortcut
        title = newShortcut.label
        onRecord?(newShortcut)
    }
}
