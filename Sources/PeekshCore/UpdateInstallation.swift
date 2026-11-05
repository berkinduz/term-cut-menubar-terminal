import Foundation

public enum UpdateInstallation {
    public static func install(from staged: URL, to application: URL, relaunch: (URL) throws -> Void) throws {
        let manager = FileManager.default
        let destination = application.resolvingSymlinksInPath().standardizedFileURL
        let parent = destination.deletingLastPathComponent()
        let replacement = parent.appendingPathComponent(".peeksh-update-\(UUID()).app")
        let backup = parent.appendingPathComponent(".peeksh-previous-\(UUID()).app")
        try manager.copyItem(at: staged, to: replacement)
        defer { try? manager.removeItem(at: replacement) }
        try manager.moveItem(at: destination, to: backup)
        var installed = false
        do {
            try manager.moveItem(at: replacement, to: destination)
            installed = true
            try relaunch(destination)
        } catch {
            let failure = error
            if installed { try manager.removeItem(at: destination) }
            try manager.moveItem(at: backup, to: destination)
            throw failure
        }
        try? manager.removeItem(at: backup)
    }
}
