import Foundation

/// What changed between two snapshots.
///
/// Accounts that disappeared are taken from the older snapshot, so they keep
/// the date they followed you (or you followed them). New accounts come from
/// the newer one.
///
/// The export only identifies accounts by username, so someone who renames
/// their account shows up as one account leaving and another arriving.
public struct SnapshotDiff: Sendable {
    public let from: Snapshot
    public let to: Snapshot

    /// Started following you.
    public let newFollowers: [Account]
    /// Stopped following you (or deactivated, or renamed).
    public let lostFollowers: [Account]
    /// You started following them.
    public let newFollowing: [Account]
    /// You stopped following them.
    public let unfollowedByYou: [Account]
    /// Now follow each other, but didn't before.
    public let newMutuals: [Account]
    /// Followed each other before, but don't now, whichever side left.
    public let lostMutuals: [Account]
    /// New followers who had followed you in an even earlier snapshot, then left.
    public let returningFollowers: [Account]

    /// - Parameter earlier: snapshots older than `old`, used to spot returning
    ///   followers. Leave empty to skip that check.
    public init(from old: Snapshot, to new: Snapshot, earlier: [Snapshot] = []) {
        let oldFollowers = Set(old.followers.map(\.username))
        let newFollowerNames = Set(new.followers.map(\.username))
        let oldFollowing = Set(old.following.map(\.username))
        let newFollowingNames = Set(new.following.map(\.username))
        let oldMutuals = oldFollowers.intersection(oldFollowing)
        let newMutualNames = newFollowerNames.intersection(newFollowingNames)

        self.from = old
        self.to = new
        self.newFollowers = new.followers.filter { !oldFollowers.contains($0.username) }
        self.lostFollowers = old.followers.filter { !newFollowerNames.contains($0.username) }
        self.newFollowing = new.following.filter { !oldFollowing.contains($0.username) }
        self.unfollowedByYou = old.following.filter { !newFollowingNames.contains($0.username) }
        self.newMutuals = new.followers.filter { newMutualNames.contains($0.username) && !oldMutuals.contains($0.username) }
        self.lostMutuals = old.followers.filter { oldMutuals.contains($0.username) && !newMutualNames.contains($0.username) }

        let everFollowedBefore = Set(earlier.flatMap { $0.followers.map(\.username) })
        self.returningFollowers = newFollowers.filter { everFollowedBefore.contains($0.username) }
    }

    /// Followers who left within `interval` of following you, such as
    /// follow-for-follow accounts. Only covers lost followers whose follow
    /// date is in the export.
    public func shortStayFollowers(within interval: TimeInterval) -> [Account] {
        lostFollowers.filter { account in
            guard let followed = account.date else { return false }
            return to.capturedAt.timeIntervalSince(followed) <= interval
        }
    }

    public var netFollowerChange: Int {
        to.followers.count - from.followers.count
    }

    public var isEmpty: Bool {
        newFollowers.isEmpty && lostFollowers.isEmpty && newFollowing.isEmpty && unfollowedByYou.isEmpty
    }
}
