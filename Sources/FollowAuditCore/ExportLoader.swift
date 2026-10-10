import Foundation

/// Loads an Instagram export (the downloaded `.zip`, or a folder it was
/// extracted to) and compares followers with following.
public enum ExportLoader {
    public static func load(from url: URL) throws -> Audit {
        let files: [ExportFile]
        if url.hasDirectoryPath || (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            files = try folderFiles(in: url)
        } else if url.pathExtension.lowercased() == "zip" {
            files = try zipFiles(in: url)
        } else {
            throw AuditError.unsupportedFile
        }
        return try audit(from: files)
    }

    // MARK: - Finding the files

    private struct ExportFile {
        enum Kind { case following, followers, html }
        let kind: Kind
        let path: String
        let read: () throws -> Data
    }

    private static func kind(ofFileAt path: String) -> ExportFile.Kind? {
        let components = path.split(separator: "/")
        guard let name = components.last?.lowercased(), !components.contains("__MACOSX") else { return nil }

        if name == "following.json" { return .following }
        if name.wholeMatch(of: /followers(_\d+)?\.json/) != nil { return .followers }
        if name == "following.html" || name.wholeMatch(of: /followers(_\d+)?\.html/) != nil { return .html }
        return nil
    }

    private static func folderFiles(in folder: URL) throws -> [ExportFile] {
        let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        var files: [ExportFile] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            if let kind = kind(ofFileAt: fileURL.path) {
                files.append(ExportFile(kind: kind, path: fileURL.path) { try Data(contentsOf: fileURL) })
            }
        }
        return files
    }

    private static func zipFiles(in zipURL: URL) throws -> [ExportFile] {
        let archive = try ZipArchive(url: zipURL)
        return archive.entries.compactMap { entry in
            kind(ofFileAt: entry.path).map { kind in
                ExportFile(kind: kind, path: entry.path) { try archive.contents(of: entry) }
            }
        }
    }

    // MARK: - Comparing

    private static func audit(from files: [ExportFile]) throws -> Audit {
        let following = files.filter { $0.kind == .following }
        // followers_1.json, followers_2.json, … in order.
        let followers = files.filter { $0.kind == .followers }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        if following.isEmpty && followers.isEmpty && files.contains(where: { $0.kind == .html }) {
            throw AuditError.htmlExport
        }
        guard !following.isEmpty else { throw AuditError.missingFollowing }
        guard !followers.isEmpty else { throw AuditError.missingFollowers }

        return Audit(
            following: try following.flatMap { try ExportParser.parseAccounts(from: $0.read()) },
            followers: try followers.flatMap { try ExportParser.parseAccounts(from: $0.read()) }
        )
    }
}

// MARK: - When the export was taken

extension ExportLoader {
    /// A best guess at when Instagram produced the export at `url`.
    ///
    /// Instagram's download names usually include the date, like
    /// `instagram-name-2026-10-10-AbC123.zip`, so that comes first. Otherwise
    /// the file's creation date, which is roughly when it was downloaded or
    /// extracted. Neither can be earlier than the newest follow in the data.
    public static func estimatedCaptureDate(for url: URL, audit: Audit) -> Date? {
        let newestFollow = Snapshot.suggestedCaptureDate(following: audit.following, followers: audit.followers)
        let hint = date(inFileName: url.deletingPathExtension().lastPathComponent)
            ?? (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
        return [hint, newestFollow].compactMap { $0 }.max()
    }

    /// The first `YYYY-MM-DD` in a file name, as midday UTC so it shows as the
    /// same day in any time zone.
    static func date(inFileName name: String) -> Date? {
        guard let match = name.firstMatch(of: /(\d{4})-(\d{2})-(\d{2})/),
              let year = Int(match.1), let month = Int(match.2), let day = Int(match.3)
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard components.isValidDate(in: calendar), (2010...2100).contains(year) else { return nil }
        return calendar.date(from: components)
    }
}
