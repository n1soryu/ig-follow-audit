import FollowAuditCore
import Foundation
import Observation

@MainActor @Observable
final class AppModel {
    enum ListKind: String, CaseIterable, Identifiable {
        case notFollowingBack, fans, following, followers
        var id: Self { self }

        var title: String {
            switch self {
            case .notFollowingBack: "Not Following Back"
            case .fans: "Fans"
            case .following: "Following"
            case .followers: "Followers"
            }
        }

        var subtitle: String {
            switch self {
            case .notFollowingBack: "People you follow who don't follow you back."
            case .fans: "People who follow you that you don't follow back."
            case .following: "Everyone you follow."
            case .followers: "Everyone who follows you."
            }
        }

        var systemImage: String {
            switch self {
            case .notFollowingBack: "person.badge.minus"
            case .fans: "heart"
            case .following: "person.badge.plus"
            case .followers: "person.2"
            }
        }

        /// What the date in the export means for this list.
        var dateTitle: String {
            switch self {
            case .notFollowingBack, .following: "Followed On"
            case .fans, .followers: "Followed You On"
            }
        }

        var emptyTitle: String {
            switch self {
            case .notFollowingBack: "Everyone Follows You Back"
            case .fans: "You Follow Everyone Back"
            case .following: "You Don't Follow Anyone"
            case .followers: "No Followers Yet"
            }
        }

        var fileName: String {
            switch self {
            case .notFollowingBack: "not-following-back"
            case .fans: "fans"
            case .following: "following"
            case .followers: "followers"
            }
        }
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
        accounts(in: listKind)
    }

    func accounts(in kind: ListKind) -> [Account] {
        guard let audit else { return [] }
        switch kind {
        case .notFollowingBack: return audit.notFollowingBack
        case .fans: return audit.fans
        case .following: return audit.following
        case .followers: return audit.followers
        }
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
