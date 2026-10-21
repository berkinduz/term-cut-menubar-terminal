import AppKit
import Carbon
import ServiceManagement
import SwiftUI
import TermCutCore

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
                ? "Allow term-cut in System Settings → General → Login Items." : nil
        } catch {
            refresh()
            message = "Could not update login items. Move term-cut to Applications and try again."
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var hotKeys: HotKeyManager
    @ObservedObject var workspace: TerminalWorkspace
    @StateObject private var login = LoginItemStore()
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "terminal").font(.system(size: 23, weight: .light))
                    .foregroundStyle(.teal).frame(width: 48, height: 48)
                    .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
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
                if matches("general startup mode login pin menu bar launch hide visibility compact drop-down") {
                    Section("General") {
                        Picker("Window mode", selection: $workspace.mode) {
                            Text("Compact panel").tag(PanelMode.compact)
                            Text("Drop-down terminal").tag(PanelMode.dropDown)
                        }
                        Toggle("Show terminal on launch", isOn: $settings.value.showOnLaunch)
                        Toggle("Keep visible when switching apps", isOn: $settings.value.keepVisible)
                        Toggle("Launch at login", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
                        if let message = login.message {
                            Text(message).font(.caption).foregroundStyle(.secondary)
                            Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                        }
                        Text("Closing the panel keeps your sessions running. Quit term-cut to end them.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if matches("appearance theme color font size typography glass motion animations status bar dim padding") {
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
                        Toggle("Glass controls", isOn: $settings.value.glassEnabled)
                        Toggle("Animate window transitions", isOn: $settings.value.animationsEnabled)
                        Toggle("Dim inactive panes", isOn: $settings.value.dimInactivePanes)
                        Toggle("Show status bar", isOn: $settings.value.showStatusBar)
                        Text("Glass controls use Liquid Glass on macOS 26 and later. Motion and transparency follow your accessibility settings.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if matches("window panel compact drop-down dropdown width height size") {
                    Section("Windows") {
                        numberSlider("Compact width", value: $settings.value.compactWidth, range: 520...1200, step: 10,
                                     label: "\(Int(settings.value.compactWidth)) pt")
                        numberSlider("Compact height", value: $settings.value.compactHeight, range: 300...850, step: 10,
                                     label: "\(Int(settings.value.compactHeight)) pt")
                        numberSlider("Drop-down width", value: $settings.value.dropDownWidth, range: 0.5...1, step: 0.05,
                                     label: "\(Int((settings.value.dropDownWidth * 100).rounded()))%")
                        numberSlider("Drop-down height", value: $settings.value.dropDownHeight, range: 0.3...0.9, step: 0.05,
                                     label: "\(Int((settings.value.dropDownHeight * 100).rounded()))%")
                        Text("You can also drag the window edges and pane dividers to resize them.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if matches("terminal shell cursor blink scrollback history option meta directory panes tabs") {
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

                if matches("keyboard shortcuts hotkey keybind global compact drop-down split tabs find focus zoom") {
                    Section("Keyboard Shortcuts") {
                        Toggle("Enable global shortcuts", isOn: $settings.value.shortcutsEnabled)
                        HStack {
                            Text("Toggle compact panel"); Spacer()
                            ShortcutRecorder(shortcut: $settings.value.compactShortcut)
                                .frame(width: 170, height: 27).disabled(!settings.value.shortcutsEnabled)
                        }
                        HStack {
                            Text("Toggle drop-down terminal"); Spacer()
                            ShortcutRecorder(shortcut: $settings.value.dropDownShortcut)
                                .frame(width: 170, height: 27).disabled(!settings.value.shortcutsEnabled)
                        }
                        if let error = hotKeys.error { Text(error).font(.caption).foregroundStyle(.orange) }
                        Text("Click a shortcut to record a new combination. Press Escape to cancel. Global shortcuts work without Accessibility permission.")
                            .font(.caption).foregroundStyle(.secondary)
                        shortcutRow("New tab", "⌘T")
                        shortcutRow("Split right / down", "⌘D / ⇧⌘D")
                        shortcutRow("Next / previous pane", "⌘] / ⌘[")
                        shortcutRow("Focus pane", "⇧⌘Return")
                        shortcutRow("Find in terminal", "⌘F")
                        shortcutRow("Close pane", "⌘W")
                        shortcutRow("Hide terminal", "⇧⌘H")
                    }
                }

                Section {
                    HStack {
                        Text("Your sessions stay open when settings change.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Restore Defaults") { settings.reset() }.controlSize(.small)
                    }
                }
                Section("About term-cut") {
                    AboutContent(compact: true).frame(maxWidth: .infinity).padding(.vertical, 14)
                }
            }
            .formStyle(.grouped).scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.teal)
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login.refresh() }
    }

    private func matches(_ terms: String) -> Bool { search.isEmpty || terms.localizedCaseInsensitiveContains(search) }
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
