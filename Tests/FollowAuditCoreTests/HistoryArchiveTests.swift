import Foundation
import Testing
@testable import FollowAuditCore

private func makeStore() -> SnapshotStore {
    SnapshotStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ig-follow-audit-archive-\(UUID().uuidString)"))
}

private func snapshot(followers: [String], at seconds: TimeInterval) -> Snapshot {
    Snapshot(following: [], followers: followers.map { Account(username: $0) }, capturedAt: Date(timeIntervalSince1970: seconds))
}

@Suite struct UserStateTests {
    @Test func missingUntilSaved() throws {
        let store = makeStore()
        #expect(try store.loadState() == nil)
        try store.saveState(UserState(done: ["alice"]))
        #expect(try store.loadState() == UserState(done: ["alice"]))
    }

    @Test func deleteAllDataRemovesSnapshotsAndState() throws {
        let store = makeStore()
        try store.add(snapshot(followers: ["alice"], at: 1))
        try store.saveState(UserState(done: ["alice"]))
        try store.deleteAllData()
        #expect(try store.load().snapshots.isEmpty)
        #expect(try store.loadState() == nil)
    }
}

@Suite struct HistoryArchiveTests {
    @Test func roundTripsThroughAFile() throws {
        let source = makeStore()
        let a = snapshot(followers: ["alice"], at: 1_000)
        let b = snapshot(followers: ["alice", "bob"], at: 2_000)
        try source.add(a)
        try source.add(b)
        try source.saveState(UserState(done: ["carol"]))

        let data = try source.makeArchive().encoded()
        let target = makeStore()
        let result = try target.restore(HistoryArchive.decode(data))

        #expect(result == SnapshotStore.RestoreResult(added: 2, skipped: 0))
        #expect(try target.load().snapshots == [a, b])
        #expect(try target.loadState() == UserState(done: ["carol"]))
    }

    @Test func restoreMergesWithoutDuplicating() throws {
        let store = makeStore()
        let existing = snapshot(followers: ["alice"], at: 1_000)
        try store.add(existing)
        try store.saveState(UserState(done: ["alice"]))

        let sameContents = snapshot(followers: ["alice"], at: 1_500)
        let new = snapshot(followers: ["bob"], at: 2_000)
        let result = try store.restore(HistoryArchive(snapshots: [sameContents, new], state: UserState(done: ["bob"])))

        #expect(result == SnapshotStore.RestoreResult(added: 1, skipped: 1))
        #expect(try store.load().snapshots == [existing, new])
        #expect(try store.loadState() == UserState(done: ["alice", "bob"]))
    }

    @Test func rejectsOtherFiles() {
        #expect(throws: HistoryArchiveError.notABackup) { try HistoryArchive.decode(Data("[]".utf8)) }
        #expect(throws: HistoryArchiveError.notABackup) { try HistoryArchive.decode(Data(#"{"format": "something-else", "version": 1}"#.utf8)) }
        #expect(throws: HistoryArchiveError.newerVersion) {
            try HistoryArchive.decode(Data(#"{"format": "ig-follow-audit-history", "version": 99}"#.utf8))
        }
        #expect(throws: HistoryArchiveError.newerVersion) {
            try HistoryArchive.decode(Data(#"{"format": "ig-follow-audit-history", "version": 1, "snapshots": [{"schemaVersion": 99}]}"#.utf8))
        }
        #expect(throws: HistoryArchiveError.damaged) {
            try HistoryArchive.decode(Data(#"{"format": "ig-follow-audit-history", "version": 1}"#.utf8))
        }
    }
}

@Suite struct CaptureDateTests {
    @Test func readsDateFromInstagramFileName() {
        let date = ExportLoader.date(inFileName: "instagram-someone-2026-10-10-AbC123")
        #expect(date == Date(timeIntervalSince1970: 1_791_633_600))  // 2026-10-10 12:00 UTC
        #expect(ExportLoader.date(inFileName: "instagram-export") == nil)
        #expect(ExportLoader.date(inFileName: "x-2026-13-40") == nil)
    }

    @Test func neverEarlierThanNewestFollow() throws {
        let audit = Audit(following: [Account(username: "a", date: Date(timeIntervalSince1970: 1_900_000_000))], followers: [])
        let url = URL(fileURLWithPath: "/nonexistent/instagram-someone-2026-10-10-x.zip")
        #expect(ExportLoader.estimatedCaptureDate(for: url, audit: audit) == Date(timeIntervalSince1970: 1_900_000_000))
    }

    @Test func historyFindsDiffForSnapshot() {
        let a = snapshot(followers: ["alice"], at: 1)
        let b = snapshot(followers: ["bob"], at: 2)
        let history = SnapshotHistory(snapshots: [b, a])
        #expect(history.diff(to: a.id) == nil)
        #expect(history.diff(to: b.id)?.newFollowers.map(\.username) == ["bob"])
    }
}
