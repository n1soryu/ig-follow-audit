import Foundation

/// All saved snapshots in date order, with the changes between each pair.
public struct SnapshotHistory: Sendable {
    /// One point per snapshot, for charting counts over time.
    public struct Point: Sendable, Identifiable {
        public let id: Snapshot.ID
        public let date: Date
        public let followers: Int
        public let following: Int
        public let mutuals: Int
    }

    /// Oldest first, by `capturedAt`.
    public let snapshots: [Snapshot]

    public init(snapshots: [Snapshot]) {
        self.snapshots = snapshots.sorted { ($0.capturedAt, $0.importedAt) < ($1.capturedAt, $1.importedAt) }
    }

    public var latest: Snapshot? { snapshots.last }

    public var points: [Point] {
        snapshots.map { snapshot in
            let followers = Set(snapshot.followers.map(\.username))
            return Point(
                id: snapshot.id,
                date: snapshot.capturedAt,
                followers: snapshot.followers.count,
                following: snapshot.following.count,
                mutuals: snapshot.following.filter { followers.contains($0.username) }.count
            )
        }
    }

    /// Changes between each snapshot and the one before it, oldest first.
    public var diffs: [SnapshotDiff] {
        snapshots.indices.dropFirst().map(diff(endingAt:))
    }

    /// What changed since the previous snapshot: the "since last time" summary.
    public var latestDiff: SnapshotDiff? {
        snapshots.count < 2 ? nil : diff(endingAt: snapshots.count - 1)
    }

    private func diff(endingAt index: Int) -> SnapshotDiff {
        SnapshotDiff(from: snapshots[index - 1], to: snapshots[index], earlier: Array(snapshots[..<(index - 1)]))
    }
}
