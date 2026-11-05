import Foundation
import PeekshCore

/// In-memory unless the app explicitly supplies defaults; tests never touch the app's saved frames.
final class WindowPlacementStore {
    private let defaults: UserDefaults?
    private let key = "floatingWindowFrames.v1"
    private var frames: [String: RememberedPanelFrame]

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        frames = defaults?.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([String: RememberedPanelFrame].self, from: $0) } ?? [:]
    }

    func frame(for screenID: String) -> RememberedPanelFrame? { frames[screenID] }

    func save(_ frame: RememberedPanelFrame, for screenID: String) {
        frames[screenID] = frame
        if let data = try? JSONEncoder().encode(frames) { defaults?.set(data, forKey: key) }
    }
}
