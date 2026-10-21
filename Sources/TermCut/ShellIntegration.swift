import Foundation

enum ShellIntegration {
    // Private status reports leave SwiftTerm's standard OSC handlers intact.
    static let statusCode = 7777

    static var zshDirectory: String {
        let resources = Bundle.main.url(forResource: "ShellIntegration", withExtension: nil)
            ?? Bundle.module.resourceURL!.appendingPathComponent("ShellIntegration")
        return resources.appendingPathComponent("zsh").path
    }
}
