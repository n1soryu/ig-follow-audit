import Foundation

/// Saves snapshots as one JSON file each, in a folder the app owns.
///
/// In the sandboxed app the default folder is inside the app's container:
/// `~/Library/Containers/<bundle id>/Data/Library/Application Support/IG Follow Audit/snapshots/`.
/// Files are named by snapshot ID rather than date, so correcting a snapshot's
/// date never means renaming its file.
public struct SnapshotStore: Sendable {
    /// The app's data folder. Snapshots live in its `snapshots` subfolder.
    public let directory: URL

    public var snapshotsDirectory: URL {
        directory.appendingPathComponent("snapshots", isDirectory: true)
    }

    public init(directory: URL) {
        self.directory = directory
    }

    /// `Application Support/IG Follow Audit`. Inside the sandbox, macOS maps
    /// this into the app's own container.
    public static func defaultDirectory() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("IG Follow Audit", isDirectory: true)
    }

    // MARK: - Reading

    public struct Contents: Sendable {
        /// Oldest first, by `capturedAt`.
        public let snapshots: [Snapshot]
        /// Files that couldn't be read: damaged, or written by a newer version
        /// of the app. They're left on disk untouched.
        public let unreadableFiles: [URL]
    }

    public func load() throws -> Contents {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: snapshotsDirectory.path) else {
            return Contents(snapshots: [], unreadableFiles: [])
        }

        let files = try fileManager
            .contentsOfDirectory(at: snapshotsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter { $0.pathExtension == "json" }

        var snapshots: [Snapshot] = []
        var unreadable: [URL] = []
        for file in files {
            if let snapshot = try? Self.decode(Data(contentsOf: file)) {
                snapshots.append(snapshot)
            } else {
                unreadable.append(file)
            }
        }
        return Contents(
            snapshots: snapshots.sorted { ($0.capturedAt, $0.importedAt) < ($1.capturedAt, $1.importedAt) },
            unreadableFiles: unreadable.sorted { $0.lastPathComponent < $1.lastPathComponent }
        )
    }

    // MARK: - Writing

    public enum AddResult: Equatable, Sendable {
        case added
        /// An existing snapshot has exactly the same contents. Nothing was written.
        case duplicate(of: Snapshot)
    }

    /// Saves a newly imported snapshot, unless the same export is already stored.
    @discardableResult
    public func add(_ snapshot: Snapshot) throws -> AddResult {
        if let existing = try load().snapshots.first(where: { $0.fingerprint == snapshot.fingerprint && $0.id != snapshot.id }) {
            return .duplicate(of: existing)
        }
        try write(snapshot)
        return .added
    }

    /// Saves changes to a snapshot that's already stored, such as a corrected date.
    public func update(_ snapshot: Snapshot) throws {
        guard FileManager.default.fileExists(atPath: url(for: snapshot.id).path) else {
            throw SnapshotError.notFound
        }
        try write(snapshot)
    }

    public func delete(id: Snapshot.ID) throws {
        let file = url(for: id)
        guard FileManager.default.fileExists(atPath: file.path) else { throw SnapshotError.notFound }
        try FileManager.default.removeItem(at: file)
    }

    /// Removes every snapshot, including unreadable files.
    public func deleteAll() throws {
        if FileManager.default.fileExists(atPath: snapshotsDirectory.path) {
            try FileManager.default.removeItem(at: snapshotsDirectory)
        }
    }

    // MARK: - Files

    func url(for id: Snapshot.ID) -> URL {
        snapshotsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func write(_ snapshot: Snapshot) throws {
        try FileManager.default.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
        // Atomic, so a crash mid-write can't leave a half-written snapshot.
        try Self.encode(snapshot).write(to: url(for: snapshot.id), options: .atomic)
    }

    // MARK: - Encoding

    static func encode(_ snapshot: Snapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    static func decode(_ data: Data) throws -> Snapshot {
        struct Header: Decodable { let schemaVersion: Int }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let header = try decoder.decode(Header.self, from: data)
        guard header.schemaVersion <= Snapshot.currentSchemaVersion else {
            throw SnapshotError.newerVersion
        }
        return try decoder.decode(Snapshot.self, from: data)
    }
}

public enum SnapshotError: LocalizedError, Equatable {
    case notFound
    case newerVersion

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "That snapshot no longer exists."
        case .newerVersion:
            return "This snapshot was saved by a newer version of IG Follow Audit. Update the app to read it."
        }
    }
}
