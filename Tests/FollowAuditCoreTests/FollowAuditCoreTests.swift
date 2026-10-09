import Foundation
import Testing
@testable import FollowAuditCore

@Suite struct ParserTests {
    @Test func parsesFollowersArrayWithValue() throws {
        let accounts = try ExportParser.parseAccounts(from: Data(Fixtures.followersJSON(["alice", "bob.smith"]).utf8))
        #expect(accounts.map(\.username) == ["alice", "bob.smith"])
        #expect(accounts[0].date == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func parsesNewerFollowingLayoutWithTitleOnly() throws {
        let accounts = try ExportParser.parseAccounts(from: Data(Fixtures.followingJSON(["carol_1", "dave"]).utf8))
        #expect(accounts.map(\.username) == ["carol_1", "dave"])
    }

    @Test func fallsBackToHrefWhenNoValueOrTitle() throws {
        let json = #"[{"title": "", "string_list_data": [{"href": "https://www.instagram.com/_u/erin.x", "timestamp": 1}]}]"#
        #expect(try ExportParser.parseAccounts(from: Data(json.utf8)).map(\.username) == ["erin.x"])
    }

    @Test func parsesOlderWrappedFollowingWithValue() throws {
        let json = #"{"relationships_following": [{"title": "", "string_list_data": [{"href": "https://www.instagram.com/Frank", "value": "Frank", "timestamp": 5}]}]}"#
        #expect(try ExportParser.parseAccounts(from: Data(json.utf8)).map(\.username) == ["frank"])
    }

    @Test func rejectsGarbage() {
        #expect(throws: AuditError.invalidJSON) { try ExportParser.parseAccounts(from: Data("nope".utf8)) }
        #expect(throws: AuditError.unrecognizedFormat) { try ExportParser.parseAccounts(from: Data(#"{"x": 1}"#.utf8)) }
    }

    @Test func usernameValidation() {
        #expect(ExportParser.isValidUsername("a.b_c9"))
        #expect(!ExportParser.isValidUsername(""))
        #expect(!ExportParser.isValidUsername("has space"))
        #expect(!ExportParser.isValidUsername(String(repeating: "a", count: 31)))
    }
}

@Suite struct AuditTests {
    @Test func comparesBothDirections() {
        let audit = Audit(
            following: ["alice", "bob", "carol"].map { Account(username: $0) },
            followers: ["bob", "dave"].map { Account(username: $0) }
        )
        #expect(audit.notFollowingBack.map(\.username) == ["alice", "carol"])
        #expect(audit.fans.map(\.username) == ["dave"])
    }

    @Test func comparisonIsCaseInsensitiveAndDeduplicates() {
        let audit = Audit(
            following: ["Alice", "alice", "BOB"].map { Account(username: $0) },
            followers: ["bob"].map { Account(username: $0) }
        )
        #expect(audit.following.count == 2)
        #expect(audit.notFollowingBack.map(\.username) == ["alice"])
    }
}

@Suite struct LoaderTests {
    let following = ["alice", "bob", "carol", "dave"]
    let followers = [["bob", "erin"], ["dave"]]  // split across followers_1 / followers_2

    @Test func loadsExtractedFolder() throws {
        let folder = try Fixtures.makeExportFolder(following: following, followers: followers)
        let audit = try ExportLoader.load(from: folder)
        #expect(audit.followers.map(\.username) == ["bob", "erin", "dave"])
        #expect(audit.notFollowingBack.map(\.username) == ["alice", "carol"])
        #expect(audit.fans.map(\.username) == ["erin"])
    }

    @Test(arguments: [false, true])
    func loadsZip(stored: Bool) throws {
        let folder = try Fixtures.makeExportFolder(following: following, followers: followers)
        let audit = try ExportLoader.load(from: Fixtures.zip(folder, stored: stored))
        #expect(audit.notFollowingBack.map(\.username) == ["alice", "carol"])
        #expect(audit.fans.map(\.username) == ["erin"])
    }

    @Test func ignoresUnrelatedFilesWithSimilarNames() throws {
        let folder = try Fixtures.makeExportFolder(
            following: following,
            followers: followers,
            extraFiles: [
                "connections/followers_and_following/following_hashtags.json": "[]",
                "__MACOSX/connections/followers_and_following/followers_9.json": "junk",
            ]
        )
        #expect(try ExportLoader.load(from: folder).followers.count == 3)
    }

    @Test func reportsHTMLExport() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("html-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "<html></html>".write(to: root.appendingPathComponent("followers_1.html"), atomically: true, encoding: .utf8)
        #expect(throws: AuditError.htmlExport) { try ExportLoader.load(from: root) }
    }

    @Test func reportsMissingFiles() throws {
        let folder = try Fixtures.makeExportFolder(following: following, followers: [])
        #expect(throws: AuditError.missingFollowers) { try ExportLoader.load(from: folder) }
    }

    @Test func rejectsNonZipFile() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-zip-\(UUID().uuidString).zip")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        #expect(throws: AuditError.self) { try ExportLoader.load(from: file) }
    }
}
