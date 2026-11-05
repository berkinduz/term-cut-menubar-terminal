import Foundation

public enum CommandCompletionPolicy {
    public static func shouldNotify(enabled: Bool, terminalVisible: Bool, duration: TimeInterval,
                                    minimumDuration: TimeInterval) -> Bool {
        enabled && !terminalVisible && duration >= minimumDuration
    }
}
