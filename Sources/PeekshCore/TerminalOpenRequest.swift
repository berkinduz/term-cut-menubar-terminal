import Foundation

public enum TerminalOpenRequest: Equatable {
    case directory(URL)
    case profile(String)

    public enum RequestError: LocalizedError {
        case invalidURL, invalidDirectory, missingValue, ambiguousRequest

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Use a peeksh://open URL with a path or profile."
            case .invalidDirectory: return "Choose an absolute directory path."
            case .missingValue: return "Provide a directory path or a profile name."
            case .ambiguousRequest: return "Open one directory or one profile at a time."
            }
        }
    }

    public init(url: URL) throws {
        guard url.scheme?.lowercased() == "peeksh", url.host == "open", url.path.isEmpty || url.path == "/",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw RequestError.invalidURL
        }
        let items = (components.queryItems ?? []).filter { $0.name == "path" || $0.name == "profile" }
        guard items.count == 1 else { throw items.isEmpty ? RequestError.missingValue : RequestError.ambiguousRequest }
        guard let value = items[0].value else { throw RequestError.missingValue }
        self = try Self.request(name: items[0].name, value: value)
    }

    public static func from(arguments: [String]) throws -> Self? {
        var result: Self?
        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            if flag == "--directory" || flag == "--profile" {
                guard result == nil else { throw RequestError.ambiguousRequest }
                index += 1
                guard index < arguments.count else { throw RequestError.missingValue }
                result = try request(name: flag == "--directory" ? "path" : "profile", value: arguments[index])
            }
            index += 1
        }
        return result
    }

    private static func request(name: String, value: String) throws -> Self {
        if name == "path" {
            guard value.hasPrefix("/"), !value.contains("\0") else { throw RequestError.invalidDirectory }
            return .directory(URL(fileURLWithPath: value).standardizedFileURL)
        }
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw RequestError.missingValue }
        return .profile(name)
    }
}
