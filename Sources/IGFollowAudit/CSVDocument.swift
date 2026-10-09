import FollowAuditCore
import SwiftUI
import UniformTypeIdentifiers

/// A list of accounts as `username,profile_url,date`.
struct CSVDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]

    let text: String

    init(accounts: [Account]) {
        let dateFormat = Date.ISO8601FormatStyle().year().month().day()
        let lines = accounts.map { account in
            // Usernames are limited to [a-z0-9._], so no quoting is needed.
            [account.username, account.profileURL.absoluteString, account.date?.formatted(dateFormat) ?? ""]
                .joined(separator: ",")
        }
        text = (["username,profile_url,date"] + lines).joined(separator: "\n") + "\n"
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
