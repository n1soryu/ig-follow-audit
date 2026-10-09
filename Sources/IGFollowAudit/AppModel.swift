import FollowAuditCore
import Foundation
import Observation

@MainActor @Observable
final class AppModel {
    enum ListKind: String, CaseIterable, Identifiable {
        case notFollowingBack, fans
        var id: Self { self }
    }

    struct LoadError: Identifiable {
        let id = UUID()
        let message: String
        let suggestion: String?
    }

    private(set) var audit: Audit?
    private(set) var sourceName: String?
    private(set) var isLoading = false
    var loadError: LoadError?
    var isImporterPresented = false
    var listKind: ListKind = .notFollowingBack {
        didSet { selection.removeAll() }
    }

    // View state. It lives here rather than in SwiftUI's @State, which is a macro
    // in the current SDK whose plugin only ships with full Xcode; Observation's
    // macros also ship with the Command Line Tools.
    var isDropTargeted = false
    var search = ""
    var selection = Set<Account.ID>()
    var sortOrder = [KeyPathComparator(\Account.sortDate, order: .reverse)]
    var isExporting = false

    /// Usernames the user has ticked off (e.g. after unfollowing them). Kept between launches.
    private(set) var done: Set<String> {
        didSet { UserDefaults.standard.set(Array(done), forKey: Self.doneKey) }
    }
    private static let doneKey = "doneUsernames"

    init() {
        done = Set(UserDefaults.standard.stringArray(forKey: Self.doneKey) ?? [])
    }

    var currentAccounts: [Account] {
        guard let audit else { return [] }
        return listKind == .notFollowingBack ? audit.notFollowingBack : audit.fans
    }

    func open(_ url: URL) {
        isLoading = true
        Task {
            // Needed for files picked in the Open panel while sandboxed.
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
                isLoading = false
            }
            do {
                audit = try await Task.detached(priority: .userInitiated) {
                    try ExportLoader.load(from: url)
                }.value
                sourceName = url.lastPathComponent
                listKind = .notFollowingBack
            } catch {
                let auditError = error as? AuditError
                loadError = LoadError(
                    message: error.localizedDescription,
                    suggestion: auditError?.recoverySuggestion
                )
            }
        }
    }

    func close() {
        audit = nil
        sourceName = nil
        search = ""
        selection.removeAll()
    }

    func isDone(_ account: Account) -> Bool {
        done.contains(account.username)
    }

    func setDone(_ isDone: Bool, for usernames: some Sequence<String>) {
        if isDone {
            done.formUnion(usernames)
        } else {
            done.subtract(usernames)
        }
    }
}
