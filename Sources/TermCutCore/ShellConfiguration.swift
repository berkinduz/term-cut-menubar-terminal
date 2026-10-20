import Foundation

public struct ShellConfiguration {
    public let executable: String
    public let arguments: [String]
    public let environment: [String]
    public let workingDirectory: String

    public init(shell: String, home: String, inheritedEnvironment: [String: String], arguments: [String] = ["-l"], workingDirectory: String? = nil) {
        executable = shell.hasPrefix("/") && !shell.isEmpty ? shell : "/bin/zsh"
        self.arguments = arguments
        self.workingDirectory = workingDirectory ?? home
        var environment = inheritedEnvironment
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        environment["TERM_PROGRAM"] = "term-cut"
        environment["TERM_PROGRAM_VERSION"] = "0.1.0"
        environment["HOME"] = home
        environment["SHELL"] = executable
        let inheritedPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        var paths = inheritedPath.split(separator: ":").map(String.init)
        for path in ["/opt/homebrew/bin", "/usr/local/bin"].reversed() where !paths.contains(path) {
            paths.insert(path, at: 0)
        }
        environment["PATH"] = paths.joined(separator: ":")
        self.environment = environment.keys.sorted().map { "\($0)=\(environment[$0]!)" }
    }
}
