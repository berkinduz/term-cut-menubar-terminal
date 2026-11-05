import AppKit

enum ProfileActions {
    static func saveCurrent(_ workspace: TerminalWorkspace) {
        prompt(workspace, title: "Save Project Profile", initialName: "",
               message: "Save these tabs, folders, and split panes. Saving an existing name replaces that profile.",
               button: "Save Profile") { name in workspace.saveProfile(name: name) }
    }

    static func rename(_ id: UUID, name: String, workspace: TerminalWorkspace) {
        prompt(workspace, title: "Rename Project Profile", initialName: name,
               message: "Choose a unique profile name. The saved layout stays the same.", button: "Rename") {
            workspace.renameProfile(id, name: $0)
        }
    }

    private static func prompt(_ workspace: TerminalWorkspace, title: String, initialName: String,
                               message: String, button: String, action: (String) -> Bool) {
        let wasPreventingAutoHide = workspace.preventsAutoHide
        workspace.preventsAutoHide = true
        defer { workspace.preventsAutoHide = wasPreventingAutoHide }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        let field = NSTextField(string: initialName)
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        field.setAccessibilityLabel("Profile name")
        alert.accessoryView = field
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard action(field.stringValue) else {
            let error = NSAlert()
            error.messageText = "Could Not Save Profile"
            error.informativeText = workspace.persistenceError ?? "Use a nonempty name. When renaming, choose a name that is not already in use."
            error.runModal()
            return
        }
    }
}
