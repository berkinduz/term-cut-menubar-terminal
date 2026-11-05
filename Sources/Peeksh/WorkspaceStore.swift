import Foundation
import PeekshCore

/// Deliberately contains layout metadata only. Processes, commands, output and environments are never encoded.
struct WorkspaceSnapshot: Codable, Equatable {
    struct Session: Codable, Equatable {
        let id: UUID
        let directory: String
    }
    struct Tab: Codable, Equatable {
        let id: UUID
        let root: PaneTree
        let customName: String?
        let selectedPaneID: UUID?
    }
    var sessions: [Session]
    var tabs: [Tab]
    var activeTabID: UUID?
    var splitFractions: [String: Double]
    var mode: PanelMode

    var isValid: Bool {
        let ids = sessions.map(\.id)
        let leaves = tabs.flatMap { $0.root.leaves }
        return Set(ids).count == ids.count && Set(tabs.map(\.id)).count == tabs.count
            && Set(leaves).count == leaves.count && Set(ids) == Set(leaves)
    }

    /// Cloning remaps the pane-tree IDs, selected pane IDs and ratio keys together.
    func cloned() -> WorkspaceSnapshot {
        let paneIDs = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, UUID()) })
        let tabIDs = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, UUID()) })
        func clone(_ tree: PaneTree) -> PaneTree {
            switch tree {
            case .leaf(let id): return .leaf(paneIDs[id]!)
            case .split(let axis, let first, let second): return .split(axis, clone(first), clone(second))
            }
        }
        var ratios: [String: Double] = [:]
        for (key, value) in splitFractions {
            let components = key.split(separator: ":").map(String.init)
            guard components.count == 3, let first = UUID(uuidString: components[1]),
                  let second = UUID(uuidString: components[2]), let a = paneIDs[first], let b = paneIDs[second] else { continue }
            ratios["\(components[0]):\(a):\(b)"] = value
        }
        return WorkspaceSnapshot(
            sessions: sessions.map { .init(id: paneIDs[$0.id]!, directory: $0.directory) },
            tabs: tabs.map { .init(id: tabIDs[$0.id]!, root: clone($0.root), customName: $0.customName,
                                  selectedPaneID: $0.selectedPaneID.flatMap { paneIDs[$0] }) },
            activeTabID: activeTabID.flatMap { tabIDs[$0] }, splitFractions: ratios, mode: mode)
    }
}

struct WorkspaceProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var snapshot: WorkspaceSnapshot
}

struct SavedWorkspace: Codable {
    var version = 1
    var workspace: WorkspaceSnapshot?
    var profiles: [WorkspaceProfile] = []
}

/// File writes replace one metadata document atomically. Tests can inject a private directory or defaults suite.
final class WorkspaceStore {
    private let fileURL: URL?
    private let defaults: UserDefaults?
    private let key: String

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("workspace.json")
        defaults = nil
        key = "workspace"
    }

    init(defaults: UserDefaults, key: String = "workspace") {
        fileURL = nil
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> SavedWorkspace {
        let data: Data
        if let fileURL {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return SavedWorkspace() }
            data = try Data(contentsOf: fileURL)
        } else {
            guard let saved = defaults?.data(forKey: key) else { return SavedWorkspace() }
            data = saved
        }
        let saved = try JSONDecoder().decode(SavedWorkspace.self, from: data)
        guard saved.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return saved
    }

    func save(_ saved: SavedWorkspace) throws {
        let data = try JSONEncoder().encode(saved)
        if let fileURL {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } else {
            defaults?.set(data, forKey: key)
        }
    }
}
