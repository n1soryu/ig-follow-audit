import Foundation
import Testing
@testable import FollowAuditCore

private let day: TimeInterval = 86_400

private func snapshot(
    following: [String],
    followers: [String],
    day number: Double,
    followerDates: [String: Double] = [:]
) -> Snapshot {
    Snapshot(
        following: following.map { Account(username: $0) },
        followers: followers.map { name in
            Account(username: name, date: followerDates[name].map { Date(timeIntervalSince1970: $0 * day) })
        },
        capturedAt: Date(timeIntervalSince1970: number * day)
    )
}

@Suite struct SnapshotDiffTests {
    @Test func findsChangesInBothDirections() {
        let old = snapshot(following: ["alice", "bob", "carol"], followers: ["alice", "bob", "dave"], day: 10)
        let new = snapshot(following: ["alice", "carol", "erin"], followers: ["alice", "carol", "frank"], day: 40)
        let diff = SnapshotDiff(from: old, to: new)

        #expect(diff.newFollowers.map(\.username) == ["carol", "frank"])
        #expect(diff.lostFollowers.map(\.username) == ["bob", "dave"])
        #expect(diff.newFollowing.map(\.username) == ["erin"])
        #expect(diff.unfollowedByYou.map(\.username) == ["bob"])
        #expect(diff.newMutuals.map(\.username) == ["carol"])
        #expect(diff.lostMutuals.map(\.username) == ["bob"])
        #expect(diff.netFollowerChange == 0)
        #expect(!diff.isEmpty)
    }

    @Test func identicalSnapshotsHaveNoChanges() {
        let a = snapshot(following: ["alice"], followers: ["bob"], day: 1)
        let b = snapshot(following: ["alice"], followers: ["bob"], day: 2)
        #expect(SnapshotDiff(from: a, to: b).isEmpty)
    }

    @Test func lostFollowersKeepTheirFollowDate() {
        let old = snapshot(following: [], followers: ["bob"], day: 10, followerDates: ["bob": 5])
        let new = snapshot(following: [], followers: [], day: 20)
        #expect(SnapshotDiff(from: old, to: new).lostFollowers.first?.date == Date(timeIntervalSince1970: 5 * day))
    }

    @Test func findsShortStayFollowers() {
        let old = snapshot(
            following: [], followers: ["quick", "loyal", "undated"], day: 30,
            followerDates: ["quick": 25, "loyal": 1]
        )
        let new = snapshot(following: [], followers: [], day: 35)
        let diff = SnapshotDiff(from: old, to: new)
        // quick stayed 10 days, loyal 34, undated is unknown.
        #expect(diff.shortStayFollowers(within: 14 * day).map(\.username) == ["quick"])
    }

    @Test func findsReturningFollowers() {
        let first = snapshot(following: [], followers: ["alice", "bob"], day: 1)
        let second = snapshot(following: [], followers: ["bob"], day: 2)
        let third = snapshot(following: [], followers: ["alice", "bob", "carol"], day: 3)
        let diff = SnapshotDiff(from: second, to: third, earlier: [first])
        #expect(diff.newFollowers.map(\.username) == ["alice", "carol"])
        #expect(diff.returningFollowers.map(\.username) == ["alice"])
    }
}

@Suite struct SnapshotHistoryTests {
    @Test func sortsAndCountsPoints() {
        let later = snapshot(following: ["alice", "bob"], followers: ["alice", "carol", "dave"], day: 20)
        let earlier = snapshot(following: ["alice"], followers: ["alice"], day: 10)
        let history = SnapshotHistory(snapshots: [later, earlier])

        #expect(history.snapshots == [earlier, later])
        #expect(history.latest == later)
        #expect(history.points.map(\.followers) == [1, 3])
        #expect(history.points.map(\.following) == [1, 2])
        #expect(history.points.map(\.mutuals) == [1, 1])
    }

    @Test func diffsConsecutivePairsAndPassesEarlierSnapshots() {
        let s1 = snapshot(following: [], followers: ["alice"], day: 1)
        let s2 = snapshot(following: [], followers: [], day: 2)
        let s3 = snapshot(following: [], followers: ["alice"], day: 3)
        let history = SnapshotHistory(snapshots: [s1, s2, s3])

        #expect(history.diffs.map(\.netFollowerChange) == [-1, 1])
        #expect(history.latestDiff?.returningFollowers.map(\.username) == ["alice"])
        #expect(history.diffs.last?.returningFollowers.map(\.username) == ["alice"])
    }

    @Test func noDiffsWithFewerThanTwoSnapshots() {
        #expect(SnapshotHistory(snapshots: []).latestDiff == nil)
        #expect(SnapshotHistory(snapshots: [snapshot(following: [], followers: [], day: 1)]).diffs.isEmpty)
    }
}
