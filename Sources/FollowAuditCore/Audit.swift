import Foundation

/// The result of comparing who you follow with who follows you.
public struct Audit: Sendable {
    public let following: [Account]
    public let followers: [Account]
    /// Accounts you follow that don't follow you back.
    public let notFollowingBack: [Account]
    /// Accounts that follow you that you don't follow back.
    public let fans: [Account]

    public init(following: [Account], followers: [Account]) {
        let following = Self.deduplicated(following)
        let followers = Self.deduplicated(followers)
        let followingNames = Set(following.map(\.username))
        let followerNames = Set(followers.map(\.username))

        self.following = following
        self.followers = followers
        self.notFollowingBack = following.filter { !followerNames.contains($0.username) }
        self.fans = followers.filter { !followingNames.contains($0.username) }
    }

    /// Keeps the first occurrence of each username, preserving order.
    private static func deduplicated(_ accounts: [Account]) -> [Account] {
        var seen = Set<String>()
        return accounts.filter { seen.insert($0.username).inserted }
    }
}
