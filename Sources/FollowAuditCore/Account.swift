import Foundation

/// One Instagram account from the export.
public struct Account: Hashable, Identifiable, Sendable {
    /// Lowercased username, used as the identity for comparisons.
    public let username: String
    /// When the relationship started (you followed them, or they followed you), if the export says.
    public let date: Date?

    public var id: String { username }

    public var profileURL: URL {
        URL(string: "https://www.instagram.com/\(username)/")!
    }

    public init(username: String, date: Date? = nil) {
        self.username = username.lowercased()
        self.date = date
    }
}
