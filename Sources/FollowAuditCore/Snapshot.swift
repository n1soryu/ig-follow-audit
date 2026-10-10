import CryptoKit
import Foundation

/// One imported export, saved so later imports can be compared with it.
///
/// Once a snapshot is saved, the export `.zip` it came from is no longer needed.
public struct Snapshot: Codable, Hashable, Identifiable, Sendable {
    /// Bump when the stored format changes in a way older code can't read.
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    /// When the export was imported into the app.
    public let importedAt: Date
    /// When the data was taken from Instagram. The export doesn't record this
    /// reliably, so it starts as a guess (see `suggestedCaptureDate`) and the
    /// user can correct it.
    public var capturedAt: Date
    public let following: [Account]
    public let followers: [Account]
    /// Identifies the contents, so importing the same export twice can be detected.
    public let fingerprint: String

    public init(
        following: [Account],
        followers: [Account],
        capturedAt: Date? = nil,
        importedAt: Date = Date(),
        id: UUID = UUID()
    ) {
        // Go through Audit so lists are deduplicated the same way everywhere.
        let audit = Audit(following: following, followers: followers)
        let importedAt = Self.wholeSeconds(importedAt)

        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.importedAt = importedAt
        self.capturedAt = Self.wholeSeconds(
            capturedAt ?? Self.suggestedCaptureDate(following: audit.following, followers: audit.followers) ?? importedAt
        )
        self.following = audit.following
        self.followers = audit.followers
        self.fingerprint = Self.fingerprint(following: audit.following, followers: audit.followers)
    }

    public init(audit: Audit, capturedAt: Date? = nil, importedAt: Date = Date()) {
        self.init(following: audit.following, followers: audit.followers, capturedAt: capturedAt, importedAt: importedAt)
    }

    public var audit: Audit {
        Audit(following: following, followers: followers)
    }

    /// The newest follow date in the data. The export was taken at or after
    /// this moment, so it's a reasonable first guess for `capturedAt`.
    public static func suggestedCaptureDate(following: [Account], followers: [Account]) -> Date? {
        (following + followers).compactMap(\.date).max()
    }

    /// SHA-256 of both lists, sorted, so the order of entries in the export doesn't matter.
    static func fingerprint(following: [Account], followers: [Account]) -> String {
        func lines(_ accounts: [Account]) -> [String] {
            accounts.map { "\($0.username)|\($0.date.map { Int($0.timeIntervalSince1970) }.map(String.init) ?? "")" }.sorted()
        }
        let text = (["following"] + lines(following) + ["followers"] + lines(followers)).joined(separator: "\n")
        return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Stored dates are ISO 8601, which keeps whole seconds only. Rounding up
    /// front means a snapshot reads back exactly as it was saved.
    private static func wholeSeconds(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }
}
