import Foundation

/// A backup of everything the app stores, as a single JSON file.
///
/// Once the export `.zip` files are deleted, the app holds the only copy of
/// the history, so this is what moves it to a new Mac or survives a reinstall.
public struct HistoryArchive: Codable, Sendable {
    /// Identifies the file as ours, so a random JSON file is rejected clearly.
    public static let formatName = "ig-follow-audit-history"
    public static let currentVersion = 1

    public let format: String
    public let version: Int
    public let exportedAt: Date
    public let snapshots: [Snapshot]
    public let state: UserState

    public init(snapshots: [Snapshot], state: UserState, exportedAt: Date = Date()) {
        self.format = Self.formatName
        self.version = Self.currentVersion
        self.exportedAt = Date(timeIntervalSince1970: exportedAt.timeIntervalSince1970.rounded(.down))
        self.snapshots = snapshots
        self.state = state
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> HistoryArchive {
        struct SnapshotHeader: Decodable { let schemaVersion: Int }
        struct Header: Decodable {
            let format: String
            let version: Int
            let snapshots: [SnapshotHeader]?
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let header = try? decoder.decode(Header.self, from: data), header.format == formatName else {
            throw HistoryArchiveError.notABackup
        }
        let snapshotsTooNew = header.snapshots?.contains { $0.schemaVersion > Snapshot.currentSchemaVersion } ?? false
        guard header.version <= currentVersion, !snapshotsTooNew else {
            throw HistoryArchiveError.newerVersion
        }
        do {
            return try decoder.decode(HistoryArchive.self, from: data)
        } catch {
            throw HistoryArchiveError.damaged
        }
    }
}

extension SnapshotStore {
    public struct RestoreResult: Equatable, Sendable {
        public let added: Int
        /// Snapshots already stored, by contents.
        public let skipped: Int
    }

    /// Adds the backup's snapshots and ticks to what's already stored.
    /// Nothing existing is removed or overwritten.
    @discardableResult
    public func restore(_ archive: HistoryArchive) throws -> RestoreResult {
        var known = Set(try load().snapshots.map(\.fingerprint))
        var added = 0
        for snapshot in archive.snapshots where !known.contains(snapshot.fingerprint) {
            try add(snapshot)
            known.insert(snapshot.fingerprint)
            added += 1
        }
        try saveState((try loadState() ?? UserState()).merged(with: archive.state))
        return RestoreResult(added: added, skipped: archive.snapshots.count - added)
    }

    public func makeArchive() throws -> HistoryArchive {
        HistoryArchive(snapshots: try load().snapshots, state: try loadState() ?? UserState())
    }
}

public enum HistoryArchiveError: LocalizedError, Equatable {
    case notABackup
    case newerVersion
    case damaged

    public var errorDescription: String? {
        switch self {
        case .notABackup:
            return "This file isn't an IG Follow Audit history backup."
        case .newerVersion:
            return "This backup was made by a newer version of IG Follow Audit. Update the app to restore it."
        case .damaged:
            return "This backup file is damaged and can't be restored."
        }
    }
}
