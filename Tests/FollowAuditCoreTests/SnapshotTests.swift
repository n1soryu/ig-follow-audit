import Foundation
import Testing
@testable import FollowAuditCore

@Suite struct SnapshotTests {
    @Test func suggestsNewestFollowDateAsCaptureDate() {
        let snapshot = Snapshot(
            following: [Account(username: "alice", date: Date(timeIntervalSince1970: 100))],
            followers: [Account(username: "bob", date: Date(timeIntervalSince1970: 300)), Account(username: "carol")],
            importedAt: Date(timeIntervalSince1970: 1_000)
        )
        #expect(snapshot.capturedAt == Date(timeIntervalSince1970: 300))
    }

    @Test func fallsBackToImportDateWithoutFollowDates() {
        let snapshot = Snapshot(following: [Account(username: "alice")], followers: [], importedAt: Date(timeIntervalSince1970: 1_000.7))
        #expect(snapshot.capturedAt == Date(timeIntervalSince1970: 1_000))
        #expect(snapshot.importedAt == Date(timeIntervalSince1970: 1_000))
    }

    @Test func deduplicatesLikeAudit() {
        let snapshot = Snapshot(following: ["Alice", "alice", "bob"].map { Account(username: $0) }, followers: [])
        #expect(snapshot.following.map(\.username) == ["alice", "bob"])
    }

    @Test func fingerprintIgnoresOrderButNotContents() {
        let a = Snapshot(following: ["alice", "bob"].map { Account(username: $0) }, followers: [Account(username: "carol")])
        let b = Snapshot(following: ["bob", "alice"].map { Account(username: $0) }, followers: [Account(username: "carol")])
        let swapped = Snapshot(following: [Account(username: "carol")], followers: ["alice", "bob"].map { Account(username: $0) })
        #expect(a.fingerprint == b.fingerprint)
        #expect(a.fingerprint != swapped.fingerprint)
    }
}

@Suite struct SnapshotStoreTests {
    let store = SnapshotStore(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent("ig-follow-audit-store-\(UUID().uuidString)")
    )

    func snapshot(_ following: [String], _ followers: [String], at seconds: TimeInterval) -> Snapshot {
        Snapshot(
            following: following.map { Account(username: $0, date: Date(timeIntervalSince1970: 50)) },
            followers: followers.map { Account(username: $0) },
            capturedAt: Date(timeIntervalSince1970: seconds)
        )
    }

    @Test func emptyWhenNothingSaved() throws {
        let contents = try store.load()
        #expect(contents.snapshots.isEmpty)
        #expect(contents.unreadableFiles.isEmpty)
    }

    @Test func roundTripsAndSortsByCaptureDate() throws {
        let newer = snapshot(["alice"], ["bob"], at: 2_000)
        let older = snapshot(["alice", "carol"], ["bob"], at: 1_000)
        try store.add(newer)
        try store.add(older)
        #expect(try store.load().snapshots == [older, newer])
    }

    @Test func skipsDuplicateImports() throws {
        let first = snapshot(["alice"], ["bob"], at: 1_000)
        let again = snapshot(["alice"], ["bob"], at: 5_000)
        #expect(try store.add(first) == .added)
        #expect(try store.add(again) == .duplicate(of: first))
        #expect(try store.load().snapshots.count == 1)
    }

    @Test func updatesCaptureDate() throws {
        var snap = snapshot(["alice"], [], at: 1_000)
        try store.add(snap)
        snap.capturedAt = Date(timeIntervalSince1970: 9_000)
        try store.update(snap)
        #expect(try store.load().snapshots.map(\.capturedAt) == [Date(timeIntervalSince1970: 9_000)])
    }

    @Test func updateAndDeleteRequireExistingSnapshot() {
        let snap = snapshot(["alice"], [], at: 1_000)
        #expect(throws: SnapshotError.notFound) { try store.update(snap) }
        #expect(throws: SnapshotError.notFound) { try store.delete(id: snap.id) }
    }

    @Test func deletesOneOrAll() throws {
        let a = snapshot(["alice"], [], at: 1_000)
        let b = snapshot(["bob"], [], at: 2_000)
        try store.add(a)
        try store.add(b)
        try store.delete(id: a.id)
        #expect(try store.load().snapshots == [b])
        try store.deleteAll()
        #expect(try store.load().snapshots.isEmpty)
    }

    @Test func reportsDamagedAndNewerFilesWithoutDeletingThem() throws {
        let good = snapshot(["alice"], [], at: 1_000)
        try store.add(good)
        let damaged = store.snapshotsDirectory.appendingPathComponent("damaged.json")
        let newer = store.snapshotsDirectory.appendingPathComponent("newer.json")
        try Data("{not json".utf8).write(to: damaged)
        try Data(#"{"schemaVersion": 999}"#.utf8).write(to: newer)

        let contents = try store.load()
        #expect(contents.snapshots == [good])
        #expect(contents.unreadableFiles.map(\.lastPathComponent) == ["damaged.json", "newer.json"])
        #expect(FileManager.default.fileExists(atPath: damaged.path))
        #expect(throws: SnapshotError.newerVersion) { try SnapshotStore.decode(Data(contentsOf: newer)) }
    }

    @Test func savesFromAnImportedExport() throws {
        let folder = try Fixtures.makeExportFolder(following: ["alice", "bob"], followers: [["bob"]])
        let snap = Snapshot(audit: try ExportLoader.load(from: folder))
        try store.add(snap)
        let loaded = try #require(store.load().snapshots.first)
        #expect(loaded.audit.notFollowingBack.map(\.username) == ["alice"])
        // Newest timestamp in the fixtures: following.json's second entry.
        #expect(loaded.capturedAt == Date(timeIntervalSince1970: 1_710_000_001))
    }
}
