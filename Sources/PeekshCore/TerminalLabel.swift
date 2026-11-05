import Foundation

public enum TerminalLabel {
    public static func directoryName(_ directory: String,
                                     home: String = FileManager.default.homeDirectoryForCurrentUser.path) -> String {
        if directory == home { return "Home" }
        guard !directory.isEmpty else { return "Terminal" }
        let folder = URL(fileURLWithPath: directory).lastPathComponent
        return folder.isEmpty || folder == "/" ? "Root" : folder
    }
}
