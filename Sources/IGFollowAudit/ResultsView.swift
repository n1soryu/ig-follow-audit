import AppKit
import FollowAuditCore
import SwiftUI

struct ResultsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let audit: Audit

    private var rows: [Account] {
        let accounts = model.currentAccounts
        let search = model.search
        let filtered = search.isEmpty ? accounts : accounts.filter { $0.username.localizedCaseInsensitiveContains(search) }
        return filtered.sorted(using: model.sortOrder)
    }

    private var dateColumnTitle: String {
        model.listKind == .notFollowingBack ? "You Followed Them" : "They Followed You"
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            summary
            Divider()
            table
            Divider()
            footer
        }
        .navigationTitle("IG Follow Audit")
        .navigationSubtitle(model.sourceName ?? "")
        .searchable(text: $model.search, placement: .toolbar, prompt: "Search usernames")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("List", selection: $model.listKind) {
                    Text("Not Following Back (\(audit.notFollowingBack.count))").tag(AppModel.ListKind.notFollowingBack)
                    Text("Fans (\(audit.fans.count))").tag(AppModel.ListKind.fans)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Export CSV", systemImage: "square.and.arrow.up") { model.isExporting = true }
                    .help("Save this list as a CSV file")
                Button("Close", systemImage: "xmark.circle") { model.close() }
                    .help("Close this export and open another")
            }
        }
        .fileExporter(
            isPresented: $model.isExporting,
            document: CSVDocument(accounts: rows),
            contentType: .commaSeparatedText,
            defaultFilename: model.listKind == .notFollowingBack ? "not-following-back" : "fans"
        ) { _ in }
    }

    // MARK: - Pieces

    private var summary: some View {
        HStack(spacing: 12) {
            StatTile(title: "Following", value: audit.following.count)
            StatTile(title: "Followers", value: audit.followers.count)
            StatTile(title: "Not Following Back", value: audit.notFollowingBack.count, highlighted: true)
            StatTile(title: "Fans", value: audit.fans.count)
        }
        .padding(16)
    }

    private var table: some View {
        @Bindable var model = model

        return Table(rows, selection: $model.selection, sortOrder: $model.sortOrder) {
            TableColumn("Done") { account in
                Toggle("Done", isOn: Binding(
                    get: { model.isDone(account) },
                    set: { model.setDone($0, for: [account.username]) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .help("Tick off accounts you've dealt with")
            }
            .width(40)

            TableColumn("Username", value: \.username) { account in
                Text(account.username)
                    .strikethrough(model.isDone(account))
                    .foregroundStyle(model.isDone(account) ? .secondary : .primary)
            }

            TableColumn(dateColumnTitle, value: \.sortDate) { account in
                Text(account.date?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    .foregroundStyle(.secondary)
            }
            .width(min: 130, ideal: 150)

            TableColumn("") { account in
                Button("Open Profile") { openURL(account.profileURL) }
                    .buttonStyle(.link)
            }
            .width(100)
        }
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
                    ContentUnavailableView(
                        model.listKind == .notFollowingBack ? "Everyone Follows You Back" : "You Follow Everyone Back",
                        systemImage: "checkmark.circle"
                    )
                } else {
                    ContentUnavailableView.search(text: model.search)
                }
            }
        }
    }

    private var footer: some View {
        let doneCount = model.currentAccounts.filter(model.isDone).count
        return HStack {
            Text("\(doneCount) of \(model.currentAccounts.count) done")
                .monospacedDigit()
            Spacer()
            Text("Double-click a row to open the profile. Unfollow in the Instagram app; this app never touches your account.")
                .lineLimit(1)
                .truncationMode(.head)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

private struct StatTile: View {
    let title: String
    let value: Int
    var highlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value, format: .number)
                .font(.title.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(highlighted ? Color.accentColor : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

extension Account {
    /// Sort key for the date column; accounts without a date sort as oldest.
    var sortDate: Date { date ?? .distantPast }
}
