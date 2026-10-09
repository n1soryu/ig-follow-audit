import Foundation

/// Builds fake Instagram exports on disk for tests.
enum Fixtures {
    /// `followers_1.json`: a top-level array, usernames in `value`.
    static func followersJSON(_ names: [String]) -> String {
        let entries = names.enumerated().map { i, name in
            """
            {"title": "", "media_list_data": [], "string_list_data": [
              {"href": "https://www.instagram.com/\(name)", "value": "\(name)", "timestamp": \(1_700_000_000 + i)}
            ]}
            """
        }
        return "[\(entries.joined(separator: ","))]"
    }

    /// `following.json`, newer layout: wrapped object, username in `title`, `_u/` hrefs, no `value`.
    static func followingJSON(_ names: [String]) -> String {
        let entries = names.enumerated().map { i, name in
            """
            {"title": "\(name)", "string_list_data": [
              {"href": "https://www.instagram.com/_u/\(name)", "timestamp": \(1_710_000_000 + i)}
            ]}
            """
        }
        return #"{"relationships_following": ["# + entries.joined(separator: ",") + "]}"
    }

    /// Writes a folder laid out like an extracted export and returns its URL.
    static func makeExportFolder(
        following: [String],
        followers: [[String]],
        extraFiles: [String: String] = [:]
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ig-follow-audit-tests-\(UUID().uuidString)")
            .appendingPathComponent("instagram-export")
        let dir = root.appendingPathComponent("connections/followers_and_following")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try followingJSON(following).write(to: dir.appendingPathComponent("following.json"), atomically: true, encoding: .utf8)
        for (i, page) in followers.enumerated() {
            try followersJSON(page).write(to: dir.appendingPathComponent("followers_\(i + 1).json"), atomically: true, encoding: .utf8)
        }
        for (path, contents) in extraFiles {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        return root
    }

    /// Zips a folder's contents. `stored` disables compression to exercise that code path.
    static func zip(_ folder: URL, stored: Bool = false) throws -> URL {
        let zipURL = folder.deletingLastPathComponent().appendingPathComponent("export-\(stored ? "stored" : "deflated").zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = folder
        process.arguments = ["-q", "-r", stored ? "-0" : "-9", zipURL.path, "."]
        try process.run()
        process.waitUntilExit()
        precondition(process.terminationStatus == 0, "zip failed")
        return zipURL
    }
}
