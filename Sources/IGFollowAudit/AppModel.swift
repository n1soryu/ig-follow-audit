import FollowAuditCore
import Foundation
import Observation

@MainActor @Observable
final class AppModel {
    enum Page: Hashable {
        case overview
        case list(ListKind)
        case snapshots
    }

    enum ListKind: String, CaseIterable, Identifiable {
        case notFollowingBack, fans, newFollowers, lostFollowers, following, followers
        var id: Self { self }

        var title: String {
            switch self {
            case .notFollowingBack: "Not Following Back"
            case .fans: "Fans"
            case .newFollowers: "New Followers"
            case .lostFollowers: "Unfollowed You"
            case .following: "Following"
            case .followers: "Followers"
            }
        }

        var subtitle: String {
            switch self {
            case .notFollowingBack: "People you follow who don't follow you back."
            case .fans: "People who follow you that you don't follow back."
            case .newFollowers: "People who started following you since the previous export."
            case .lostFollowers: "Followed you in the previous export, but not in this one. Deactivated and renamed accounts show up here too."
            case .following: "Everyone you follow."
            case .followers: "Everyone who follows you."
            }
        }

        var systemImage: String {
            switch self {
            case .notFollowingBack: "person.badge.minus"
            case .fans: "heart"
            case .newFollowers: "person.crop.circle.badge.plus"
            case .lostFollowers: "person.crop.circle.badge.minus"
            case .following: "person.badge.plus"
            case .followers: "person.2"
            }
        }

        /// What the date in the export means for this list.
        var dateTitle: String {
            switch self {
            case .notFollowingBack, .following: "Followed On"
            case .fans, .followers, .newFollowers, .lostFollowers: "Followed You On"
            }
        }

        var emptyTitle: String {
            switch self {
            case .notFollowingBack: "Everyone Follows You Back"
            case .fans: "You Follow Everyone Back"
            case .newFollowers: "No New Followers"
            case .lostFollowers: "Nobody Unfollowed You"
            case .following: "You Don't Follow Anyone"
            case .followers: "No Followers Yet"
            }
        }

        var fileName: String {
            switch self {
            case .notFollowingBack: "not-following-back"
            case .fans: "fans"
            case .newFollowers: "new-followers"
            case .lostFollowers: "unfollowed-you"
            case .following: "following"
            case .followers: "followers"
            }
        }

        /// Lists that compare two snapshots, so need at least two.
        var isChange: Bool {
            self == .newFollowers || self == .lostFollowers
        }
    }

    /// A message shown in an alert: an error, or the result of an import.
    struct Message: Identifiable {
        let id = UUID()
        let title: String
        let text: String
    }

    enum ImporterMode {
        case export, history
    }

    let store: SnapshotStore

    // MARK: Data

    /// Every saved snapshot.
    private(set) var history = SnapshotHistory(snapshots: [])
    /// Counts per snapshot, oldest first. Cached for the same reason as `audit`.
    private(set) var points: [SnapshotHistory.Point] = []
    /// Snapshot files that couldn't be read. They're left on disk.
    private(set) var unreadableFiles: [URL] = []
    /// False until saved data has been read at launch.
    private(set) var hasLoaded = false
    private(set) var isLoading = false

    /// The snapshot being looked at, or `nil` for the latest.
    var viewedSnapshotID: Snapshot.ID? {
        didSet { refresh() }
    }
    /// Lists for the viewed snapshot. Cached: the sidebar badges read them on every redraw.
    private(set) var audit: Audit?
    /// Changes between the viewed snapshot and the one before it.
    private(set) var diff: SnapshotDiff?

    /// Usernames the user has ticked off (e.g. after unfollowing them). Kept between launches.
    private(set) var done: Set<String> = []

    // MARK: View state
    // It lives here rather than in SwiftUI's @State, which is a macro in the
    // current SDK whose plugin only ships with full Xcode; Observation's macros
    // also ship with the Command Line Tools.

    var page: Page = .overview {
        // Only write when needed: every write notifies SwiftUI, even an empty set.
        didSet { if !selection.isEmpty { selection.removeAll() } }
    }
    var message: Message?
    var isImporterPresented = false
    var importerMode = ImporterMode.export
    var isDropTargeted = false
    var search = ""
    var selection = Set<Account.ID>()
    var sortOrder = [KeyPathComparator(\Account.sortDate, order: .reverse)]
    var isExporting = false
    var isExportingHistory = false
    var historyDocument: HistoryDocument?
    var isShowingExportSteps = false
    var snapshotPendingDeletion: Snapshot?
    var isConfirmingDeleteAll = false
    /// The date under the pointer on the growth chart.
    var chartSelection: Date?

    private static let legacyDoneKey = "doneUsernames"

    init() {
        store = SnapshotStore(directory: Self.dataDirectory())
        Task { await loadSavedData() }
    }

    private static func dataDirectory() -> URL {
        let env = ProcessInfo.processInfo.environment
        if let override = env["IGFA_DATA_DIR"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        #if DEBUG
        // UI test runs (see DebugSnapshot) mustn't touch real saved data.
        if env["IGFA_SNAPSHOT"] != nil || env["IGFA_SCROLLTEST"] != nil {
            return FileManager.default.temporaryDirectory.appendingPathComponent("igfa-debug-\(UUID().uuidString)")
        }
        #endif
        return (try? SnapshotStore.defaultDirectory())
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("IG Follow Audit")
    }

    // MARK: - Derived

    var currentSnapshot: Snapshot? {
        viewedSnapshotID.flatMap(history.snapshot(id:)) ?? history.latest
    }

    var isViewingLatest: Bool {
        currentSnapshot?.id == history.latest?.id
    }

    var listKind: ListKind? {
        if case .list(let kind) = page { kind } else { nil }
    }

    var currentAccounts: [Account] {
        listKind.map(accounts(in:)) ?? []
    }

    func accounts(in kind: ListKind) -> [Account] {
        switch kind {
        case .notFollowingBack: audit?.notFollowingBack ?? []
        case .fans: audit?.fans ?? []
        case .newFollowers: diff?.newFollowers ?? []
        case .lostFollowers: diff?.lostFollowers ?? []
        case .following: audit?.following ?? []
        case .followers: audit?.followers ?? []
        }
    }

    private func refresh() {
        if let id = viewedSnapshotID, history.snapshot(id: id) == nil {
            viewedSnapshotID = nil  // Calls refresh again.
            return
        }
        let snapshot = currentSnapshot
        audit = snapshot?.audit
        diff = snapshot.flatMap { history.diff(to: $0.id) }
        if let kind = listKind, kind.isChange, diff == nil {
            page = .overview
        }
        search = ""
        chartSelection = nil
    }

    private func setHistory(_ snapshots: [Snapshot]) {
        history = SnapshotHistory(snapshots: snapshots)
        points = history.points
        refresh()
    }

    // MARK: - Loading saved data

    private func loadSavedData() async {
        let store = store
        let result = await Task.detached(priority: .userInitiated) { () -> Result<(SnapshotStore.Contents, UserState?), Error> in
            Result { (try store.load(), try store.loadState()) }
        }.value

        switch result {
        case .success(let (contents, state)):
            unreadableFiles = contents.unreadableFiles
            setHistory(contents.snapshots)
            if let state {
                done = state.done
            } else {
                migrateLegacyDone()
            }
        case .failure(let error):
            message = Message(title: "Couldn't Read Saved Data", text: error.localizedDescription)
        }
        hasLoaded = true
    }

    /// Up to 1.0.1, ticks were kept in UserDefaults. Move them into state.json.
    private func migrateLegacyDone() {
        let legacy = UserDefaults.standard.stringArray(forKey: Self.legacyDoneKey) ?? []
        guard !legacy.isEmpty else { return }
        done = Set(legacy)
        if saveState() {
            UserDefaults.standard.removeObject(forKey: Self.legacyDoneKey)
        }
    }

    @discardableResult
    private func saveState() -> Bool {
        do {
            try store.saveState(UserState(done: done))
            return true
        } catch {
            message = Message(title: "Couldn't Save Your Ticks", text: error.localizedDescription)
            return false
        }
    }

    private func reloadSnapshots() async throws {
        let store = store
        let contents = try await Task.detached(priority: .userInitiated) { try store.load() }.value
        unreadableFiles = contents.unreadableFiles
        setHistory(contents.snapshots)
    }

    // MARK: - Importing exports

    func presentExportImporter() {
        importerMode = .export
        isImporterPresented = true
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
                let store = store
                let (snapshot, result) = try await Task.detached(priority: .userInitiated) {
                    let audit = try ExportLoader.load(from: url)
                    let snapshot = Snapshot(audit: audit, capturedAt: ExportLoader.estimatedCaptureDate(for: url, audit: audit))
                    return (snapshot, try store.add(snapshot))
                }.value
                try await reloadSnapshots()

                let dateText = { (date: Date) in date.formatted(date: .long, time: .omitted) }
                switch result {
                case .added:
                    viewedSnapshotID = snapshot.id == history.latest?.id ? nil : snapshot.id
                    message = Message(
                        title: "Export Saved",
                        text: "Data from \(dateText(snapshot.capturedAt)) is now in your history. "
                            + "The app keeps its own copy, so you can delete the .zip file.\n\n"
                            + "If that date is wrong, you can correct it under Snapshots."
                    )
                case .duplicate(let existing):
                    viewedSnapshotID = existing.id == history.latest?.id ? nil : existing.id
                    message = Message(
                        title: "Already Imported",
                        text: "This export is already in your history, as data from \(dateText(existing.capturedAt))."
                    )
                }
                page = .overview
            } catch {
                message = Message(
                    title: "Couldn't Open Export",
                    text: [error.localizedDescription, (error as? AuditError)?.recoverySuggestion]
                        .compactMap { $0 }.joined(separator: "\n\n")
                )
            }
        }
    }

    // MARK: - Managing snapshots

    func setCaptureDate(_ date: Date, for id: Snapshot.ID) {
        guard var snapshot = history.snapshot(id: id), snapshot.capturedAt != date else { return }
        snapshot.capturedAt = date
        do {
            try store.update(snapshot)
            setHistory(history.snapshots.map { $0.id == id ? snapshot : $0 })
        } catch {
            message = Message(title: "Couldn't Change the Date", text: error.localizedDescription)
        }
    }

    func delete(_ snapshot: Snapshot) {
        do {
            try store.delete(id: snapshot.id)
            setHistory(history.snapshots.filter { $0.id != snapshot.id })
        } catch {
            message = Message(title: "Couldn't Delete Snapshot", text: error.localizedDescription)
        }
    }

    func deleteAllData() {
        do {
            try store.deleteAllData()
            UserDefaults.standard.removeObject(forKey: Self.legacyDoneKey)
            done = []
            unreadableFiles = []
            page = .overview
            setHistory([])
        } catch {
            message = Message(title: "Couldn't Delete Data", text: error.localizedDescription)
        }
    }

    // MARK: - Backups

    func backUpHistory() {
        do {
            let archive = HistoryArchive(snapshots: history.snapshots, state: UserState(done: done))
            historyDocument = HistoryDocument(data: try archive.encoded())
            isExportingHistory = true
        } catch {
            message = Message(title: "Couldn't Back Up History", text: error.localizedDescription)
        }
    }

    var backupFileName: String {
        "IG Follow Audit History \(Date().formatted(.iso8601.year().month().day()))"
    }

    func presentHistoryImporter() {
        importerMode = .history
        isImporterPresented = true
    }

    func restoreHistory(from url: URL) {
        isLoading = true
        Task {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
                isLoading = false
            }
            do {
                let store = store
                let result = try await Task.detached(priority: .userInitiated) {
                    try store.restore(HistoryArchive.decode(Data(contentsOf: url)))
                }.value
                try await reloadSnapshots()
                done = try store.loadState()?.done ?? done
                let skipped = result.skipped == 0 ? "" : " \(result.skipped) were already here and were skipped."
                message = Message(
                    title: "History Restored",
                    text: "Added \(result.added) snapshot\(result.added == 1 ? "" : "s").\(skipped) Your ticked-off accounts were merged in."
                )
            } catch {
                message = Message(title: "Couldn't Restore History", text: error.localizedDescription)
            }
        }
    }

    // MARK: - Ticking accounts off

    func isDone(_ account: Account) -> Bool {
        done.contains(account.username)
    }

    func setDone(_ isDone: Bool, for usernames: some Sequence<String>) {
        let before = done
        if isDone {
            done.formUnion(usernames)
        } else {
            done.subtract(usernames)
        }
        if done != before { saveState() }
    }
}
