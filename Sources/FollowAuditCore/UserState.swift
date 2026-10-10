import Foundation

/// Everything the user has set by hand, as opposed to data from exports.
/// Saved as `state.json` next to the snapshots folder.
public struct UserState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion = Self.currentSchemaVersion
    /// Usernames ticked off, e.g. after unfollowing them.
    public var done: Set<String> = []

    public init(done: Set<String> = []) {
        self.done = done
    }

    /// Combines two states, e.g. when restoring a backup on top of existing data.
    public func merged(with other: UserState) -> UserState {
        UserState(done: done.union(other.done))
    }
}

extension SnapshotStore {
    public var stateURL: URL {
        directory.appendingPathComponent("state.json")
    }

    /// `nil` if nothing has been saved yet, so the app knows to migrate older settings.
    public func loadState() throws -> UserState? {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return nil }
        let data = try Data(contentsOf: stateURL)
        struct Header: Decodable { let schemaVersion: Int }
        guard try JSONDecoder().decode(Header.self, from: data).schemaVersion <= UserState.currentSchemaVersion else {
            throw SnapshotError.newerVersion
        }
        return try JSONDecoder().decode(UserState.self, from: data)
    }

    public func saveState(_ state: UserState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(state).write(to: stateURL, options: .atomic)
    }

    /// Removes snapshots and state: everything the app has stored.
    public func deleteAllData() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}
