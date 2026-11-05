import Foundation

public struct TerminalLaunchOptions {
    public enum Utility { case settings, about }

    public private(set) var request: TerminalOpenRequest?
    public private(set) var mode: PanelMode?
    public private(set) var utility: Utility?

    public init() {}

    public init(arguments: [String]) throws {
        request = try TerminalOpenRequest.from(arguments: arguments)
        var flags = Set<String>()
        var index = 0
        while index < arguments.count {
            if arguments[index] == "--directory" || arguments[index] == "--profile" {
                index += 2 // The validated request's operand is data, even when it looks like a flag.
            } else {
                flags.insert(arguments[index])
                index += 1
            }
        }
        // Legacy presentation flags now open the single menu-bar terminal window.
        if !flags.isDisjoint(with: ["--compact", "--island", "--dropdown"]) { mode = .compact }
        if flags.contains("--settings") { utility = .settings }
        else if flags.contains("--about") { utility = .about }
    }
}
