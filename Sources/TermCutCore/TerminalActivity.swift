public enum TerminalActivity: Equatable {
    case unavailable
    case ready
    case running
    case failed(Int32)
    case ended

    public init?(shellReport: String) {
        if shellReport == "start" {
            self = .running
        } else if shellReport.hasPrefix("done;"),
                  let status = Int32(shellReport.dropFirst(5)), (0...255).contains(status) {
            self = status == 0 ? .ready : .failed(status)
        } else {
            return nil
        }
    }

    public var description: String {
        switch self {
        case .unavailable: return "Activity unavailable"
        case .ready: return "Ready"
        case .running: return "Command running"
        case .failed(let status): return "Command failed (exit \(status))"
        case .ended: return "Session ended"
        }
    }

    public static func combined(_ activities: [TerminalActivity]) -> TerminalActivity {
        if let failure = activities.first(where: { if case .failed = $0 { return true }; return false }) { return failure }
        if activities.contains(.running) { return .running }
        if activities.contains(.unavailable) { return .unavailable }
        if activities.contains(.ready) { return .ready }
        return .ended
    }
}
