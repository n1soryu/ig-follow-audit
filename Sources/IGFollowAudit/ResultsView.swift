import AppKit
import FollowAuditCore
import SwiftUI

struct ResultsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            switch model.page {
            case .overview: OverviewView()
            case .list(let kind): AccountList(kind: kind)
            case .snapshots: SnapshotsView()
            }
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List(selection: Binding(get: { model.page }, set: { if let page = $0 { model.page = page } })) {
            Label("Overview", systemImage: "square.grid.2x2")
                .tag(AppModel.Page.overview)
            Section("Review") {
                row(.notFollowingBack)
                row(.fans)
            }
            if let diff = model.diff {
                Section("Since \(diff.from.capturedAt.formatted(date: .abbreviated, time: .omitted))") {
                    row(.newFollowers)
                    row(.lostFollowers)
                }
            }
            Section("Everyone") {
                row(.following)
                row(.followers)
            }
            Section("History") {
                Label("Snapshots", systemImage: "clock.arrow.circlepath")
                    .badge(model.history.snapshots.count)
                    .tag(AppModel.Page.snapshots)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { snapshotPicker }
    }

    private func row(_ kind: AppModel.ListKind) -> some View {
        Label(kind.title, systemImage: kind.systemImage)
            .badge(model.accounts(in: kind).count)
            .tag(AppModel.Page.list(kind))
    }

    /// Which snapshot is being viewed, with a menu to switch to another.
    private var snapshotPicker: some View {
        Menu {
            ForEach(model.history.snapshots.reversed()) { snapshot in
                Button {
                    model.viewedSnapshotID = snapshot.id == model.history.latest?.id ? nil : snapshot.id
                } label: {
                    if snapshot.id == model.currentSnapshot?.id {
                        Label(snapshot.capturedAt.formatted(date: .long, time: .omitted), systemImage: "checkmark")
                    } else {
                        Text(snapshot.capturedAt.formatted(date: .long, time: .omitted))
                    }
                }
            }
            Divider()
            Button("Import Export…") { model.presentExportImporter() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundStyle(Theme.gradient)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.currentSnapshot?.capturedAt.formatted(date: .abbreviated, time: .omitted) ?? "No data")
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(model.isViewingLatest ? "Latest snapshot" : "Older snapshot")
                        .font(.caption)
                        .foregroundStyle(model.isViewingLatest ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.accent))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help("Choose which snapshot to look at")
        .padding(10)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(10)
    }
}

// MARK: - Account list

private struct AccountList: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    let kind: AppModel.ListKind

    private var rows: [Account] {
        let accounts = model.currentAccounts
        let search = model.search
        let filtered = search.isEmpty ? accounts : accounts.filter { $0.username.localizedCaseInsensitiveContains(search) }
        return filtered.sorted(using: model.sortOrder)
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            header
            table
        }
        .hidingToolbarTitle()
        .navigationTitle(kind.title)
        .searchable(text: $model.search, placement: .toolbar, prompt: "Search usernames")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export CSV", systemImage: "square.and.arrow.up") { model.isExporting = true }
                    .help("Save this list as a CSV file")
            }
        }
        .fileExporter(
            isPresented: $model.isExporting,
            document: CSVDocument(accounts: rows),
            contentType: .commaSeparatedText,
            defaultFilename: kind.fileName
        ) { _ in }
    }

    private var header: some View {
        let accounts = model.currentAccounts
        let doneCount = accounts.filter(model.isDone).count

        return HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title)
                    .font(.system(size: 26, weight: .bold))
                Text(kind.subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !accounts.isEmpty {
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(doneCount) of \(accounts.count) done")
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    GradientProgressBar(fraction: Double(doneCount) / Double(accounts.count))
                }
                .help("Tick accounts off as you deal with them")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var table: some View {
        @Bindable var model = model

        return Table(rows, selection: $model.selection, sortOrder: $model.sortOrder) {
            TableColumn("") { account in
                DoneButton(model: model, account: account)
            }
            .width(28)

            TableColumn("Account", value: \.username) { account in
                let isDone = model.isDone(account)
                HStack(spacing: 10) {
                    Avatar(username: account.username)
                        .saturation(isDone ? 0 : 1)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.username)
                            .font(.body.weight(.medium))
                            .strikethrough(isDone)
                        Text("instagram.com/\(account.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .opacity(isDone ? 0.55 : 1)
                .padding(.vertical, 4)
            }

            TableColumn(kind.dateTitle, value: \.sortDate) { account in
                Text(account.date?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .width(min: 110, ideal: 130)

            TableColumn("") { account in
                Button {
                    openURL(account.profileURL)
                } label: {
                    Label("Open", systemImage: "arrow.up.right")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .help("Open \(account.username)'s profile in your browser")
            }
            .width(80)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        // A fresh table per list, search and sort. Diffing thousands of rows into an
        // existing, scrolled table makes AppKit warn about reentrant delegate calls
        // (a future assert). Tables only create visible rows, so rebuilding is cheap.
        .id(TableIdentity(kind: kind, snapshot: model.currentSnapshot?.id, search: model.search, sortOrder: model.sortOrder))
        .contextMenu(forSelectionType: Account.ID.self) { ids in
            if !ids.isEmpty {
                Button(ids.count == 1 ? "Open Profile" : "Open \(ids.count) Profiles") { openProfiles(ids) }
                Button(ids.count == 1 ? "Copy Username" : "Copy \(ids.count) Usernames") { copy(ids) }
                Divider()
                Button("Mark as Done") { model.setDone(true, for: ids) }
                Button("Mark as Not Done") { model.setDone(false, for: ids) }
            }
        } primaryAction: { ids in
            openProfiles(ids)
        }
        .overlay {
            if rows.isEmpty {
                if model.search.isEmpty {
                    ContentUnavailableView(kind.emptyTitle, systemImage: "checkmark.seal")
                } else {
                    ContentUnavailableView.search(text: model.search)
                }
            }
        }
    }

    // MARK: - Actions

    private func openProfiles(_ ids: Set<Account.ID>) {
        for account in rows where ids.contains(account.id) {
            openURL(account.profileURL)
        }
    }

    private func copy(_ ids: Set<Account.ID>) {
        let names = rows.filter { ids.contains($0.id) }.map(\.username)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(names.joined(separator: "\n"), forType: .string)
    }
}

private struct TableIdentity: Hashable {
    let kind: AppModel.ListKind
    let snapshot: Snapshot.ID?
    let search: String
    let sortOrder: [KeyPathComparator<Account>]
}

/// A round check button for ticking an account off.
///
/// Takes the model directly rather than from the environment: table rows are
/// recycled as you scroll, and recycled rows don't reliably inherit it.
private struct DoneButton: View {
    let model: AppModel
    let account: Account

    var body: some View {
        let isDone = model.isDone(account)
        Button {
            model.setDone(!isDone, for: [account.username])
        } label: {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17))
                .foregroundStyle(isDone ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.tertiary))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(isDone ? "Mark as not done" : "Mark as done")
    }
}

extension Account {
    /// Sort key for the date column; accounts without a date sort as oldest.
    var sortDate: Date { date ?? .distantPast }
}
