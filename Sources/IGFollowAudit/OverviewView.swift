import Charts
import FollowAuditCore
import SwiftUI

/// The dashboard: headline counts, what changed since the previous export,
/// and follower growth over time.
struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    /// Suggest a new export after this long.
    private static let exportInterval: TimeInterval = 30 * 86_400

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if !model.isViewingLatest { olderSnapshotBanner }
                if model.isViewingLatest, let age = latestAge, age >= Self.exportInterval { reminder(age: age) }
                tiles
                if let diff = model.diff {
                    changes(diff)
                } else {
                    firstSnapshotNote
                }
                if model.points.count >= 2 {
                    GrowthChart(model: model)
                }
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Overview")
        .hidingToolbarTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Import Export", systemImage: "square.and.arrow.down") { model.presentExportImporter() }
                    .help("Import a new Instagram export (⌘O)")
            }
        }
    }

    private var latestAge: TimeInterval? {
        model.history.latest.map { Date().timeIntervalSince($0.capturedAt) }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Overview")
                .font(.system(size: 26, weight: .bold))
            if let snapshot = model.currentSnapshot {
                Text(subtitle(for: snapshot))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func subtitle(for snapshot: Snapshot) -> String {
        let date = snapshot.capturedAt.formatted(date: .long, time: .omitted)
        if let previous = model.diff?.from {
            return "Data from \(date), compared with \(previous.capturedAt.formatted(date: .long, time: .omitted))."
        }
        return "Data from \(date)."
    }

    private var olderSnapshotBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(Theme.accent)
            Text("You're looking at an older snapshot.")
                .font(.callout.weight(.medium))
            Spacer()
            Button("Show Latest") { model.viewedSnapshotID = nil }
        }
        .padding(14)
        .card()
    }

    private func reminder(age: TimeInterval) -> some View {
        let days = Int(age / 86_400)
        return HStack(spacing: 14) {
            Image(systemName: "bell.badge")
                .font(.title2)
                .foregroundStyle(Theme.gradient)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your latest export is \(days) days old")
                    .font(.headline)
                Text("Request a new one from Instagram to see who's followed and unfollowed you since.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("How to Get an Export") { model.isShowingExportSteps = true }
            Button("Import Export…") { model.presentExportImporter() }
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .card()
    }

    // MARK: - Tiles

    private var tiles: some View {
        let audit = model.audit
        let followers = audit?.followers.count ?? 0
        let following = audit?.following.count ?? 0
        let notFollowingBack = audit?.notFollowingBack.count ?? 0
        let previous = model.diff.flatMap { diff in model.points.first { $0.id == diff.from.id } }

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 130), spacing: 14), count: 4), spacing: 14) {
            StatTile(label: "Followers", value: followers,
                     change: previous.map { followers - $0.followers }, upIsGood: true,
                     systemImage: "person.2") { model.page = .list(.followers) }
            StatTile(label: "Following", value: following,
                     change: previous.map { following - $0.following }, upIsGood: nil,
                     systemImage: "person.badge.plus") { model.page = .list(.following) }
            StatTile(label: "Mutuals", value: following - notFollowingBack,
                     change: previous.map { following - notFollowingBack - $0.mutuals }, upIsGood: true,
                     systemImage: "arrow.left.arrow.right", action: nil)
            StatTile(label: "Not following back", value: notFollowingBack,
                     change: previous.map { notFollowingBack - ($0.following - $0.mutuals) }, upIsGood: false,
                     systemImage: "person.badge.minus") { model.page = .list(.notFollowingBack) }
        }
    }

    // MARK: - Changes

    private func changes(_ diff: SnapshotDiff) -> some View {
        let shortStay = diff.shortStayFollowers(within: 30 * 86_400)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Since \(diff.from.capturedAt.formatted(date: .long, time: .omitted))")
                .font(.headline)
            if diff.isEmpty {
                Text("Nothing changed between these two exports.")
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    GridRow {
                        ChangeRow(title: "New followers", count: diff.newFollowers.count, systemImage: "person.crop.circle.badge.plus") {
                            model.page = .list(.newFollowers)
                        }
                        ChangeRow(title: "Unfollowed you", count: diff.lostFollowers.count, systemImage: "person.crop.circle.badge.minus") {
                            model.page = .list(.lostFollowers)
                        }
                    }
                    GridRow {
                        ChangeRow(title: "New mutuals", count: diff.newMutuals.count, systemImage: "arrow.left.arrow.right")
                        ChangeRow(title: "Mutuals lost", count: diff.lostMutuals.count, systemImage: "arrow.left.arrow.right.circle")
                    }
                    GridRow {
                        ChangeRow(title: "You followed", count: diff.newFollowing.count, systemImage: "plus.circle")
                        ChangeRow(title: "You unfollowed", count: diff.unfollowedByYou.count, systemImage: "minus.circle")
                    }
                }
                if !diff.returningFollowers.isEmpty {
                    NameList(
                        title: "Came back after unfollowing you",
                        accounts: diff.returningFollowers,
                        open: { openURL($0.profileURL) }
                    )
                }
                if !shortStay.isEmpty {
                    NameList(
                        title: "Unfollowed you within a month of following",
                        accounts: shortStay,
                        open: { openURL($0.profileURL) }
                    )
                }
                Text("Renamed and deactivated accounts show up as unfollows, because the export only has usernames.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var firstSnapshotNote: some View {
        HStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(Theme.gradient)
            VStack(alignment: .leading, spacing: 2) {
                Text("This is your first snapshot")
                    .font(.headline)
                Text("Import another export in a few weeks to see who followed and unfollowed you in between, and how your followers grow.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("How to Get an Export") { model.isShowingExportSteps = true }
        }
        .padding(16)
        .card()
    }
}

// MARK: - Pieces

/// A headline number with its change since the previous snapshot.
private struct StatTile: View {
    let label: String
    let value: Int
    /// `nil` when there's no previous snapshot.
    let change: Int?
    /// Whether a rise is good news (green), bad news (red), or neither (`nil`).
    let upIsGood: Bool?
    let systemImage: String
    /// Opens the matching list. `nil` when there isn't one.
    let action: (() -> Void)?

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.primary)
            changeLabel
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .card()

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .help("Show the list")
        } else {
            content
        }
    }

    @ViewBuilder private var changeLabel: some View {
        if let change {
            let icon = change > 0 ? "arrow.up.right" : change < 0 ? "arrow.down.right" : "equal"
            let text = change == 0 ? "No change" : "\(change > 0 ? "+" : "−")\(abs(change).formatted()) since last"
            Label(text, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(color(for: change))
        } else {
            Text("No earlier snapshot")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func color(for change: Int) -> Color {
        guard change != 0, let upIsGood else { return .secondary }
        return (change > 0) == upIsGood ? .green : .red
    }
}

private struct ChangeRow: View {
    let title: String
    let count: Int
    let systemImage: String
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer(minLength: 12)
            Text(count.formatted())
                .font(.body.weight(.semibold))
                .monospacedDigit()
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minWidth: 220)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .help("Show the list")
        } else {
            content
        }
    }
}

/// A short run of usernames, each opening its profile.
private struct NameList: View {
    let title: String
    let accounts: [Account]
    let open: (Account) -> Void

    private let limit = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) (\(accounts.count))")
                .font(.callout.weight(.medium))
            HStack(spacing: 6) {
                ForEach(accounts.prefix(limit)) { account in
                    Button(account.username) { open(account) }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .help("Open \(account.username)'s profile in your browser")
                }
                if accounts.count > limit {
                    Text("and \(accounts.count - limit) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Growth chart

/// Followers over time, one point per snapshot.
///
/// A separate view taking the model directly, so moving the pointer over the
/// chart only redraws the chart.
private struct GrowthChart: View {
    let model: AppModel

    /// The chart's background, also used as the ring around each point.
    private let surface = Color(nsColor: .controlBackgroundColor)

    var body: some View {
        let points = model.points
        let selected = model.chartSelection.flatMap(nearestPoint(to:))

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Followers over time")
                    .font(.headline)
                Spacer()
                Button("View as Table") { model.page = .snapshots }
                    .buttonStyle(.link)
                    .font(.callout)
            }
            Chart {
                ForEach(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Followers", point.followers))
                        .foregroundStyle(Theme.pink)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
                ForEach(points) { point in
                    // A surface-coloured disc behind each dot gives it a 2pt ring.
                    PointMark(x: .value("Date", point.date), y: .value("Followers", point.followers))
                        .symbolSize(point.id == selected?.id ? 220 : 150)
                        .foregroundStyle(surface)
                    PointMark(x: .value("Date", point.date), y: .value("Followers", point.followers))
                        .symbolSize(point.id == selected?.id ? 110 : 64)
                        .foregroundStyle(Theme.pink)
                }
                if let last = points.last, selected == nil {
                    PointMark(x: .value("Date", last.date), y: .value("Followers", last.followers))
                        .opacity(0)
                        .annotation(position: .top, spacing: 8) {
                            Text(last.followers.formatted())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                }
                if let selected {
                    RuleMark(x: .value("Date", selected.date))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .zIndex(-1)
                        .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            tooltip(for: selected)
                        }
                }
            }
            .chartYScale(domain: yDomain(points))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel(format: dateFormat(points))
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel()
                }
            }
            .chartXSelection(value: Binding(get: { model.chartSelection }, set: { model.chartSelection = $0 }))
            .frame(height: 220)
            .accessibilityLabel("Followers over time")
        }
        .padding(18)
        .card()
    }

    private func tooltip(for point: SnapshotHistory.Point) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(point.followers.formatted()) followers")
                .font(.callout.weight(.semibold))
            Text("\(point.following.formatted()) following · \(point.mutuals.formatted()) mutuals")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }

    private func nearestPoint(to date: Date) -> SnapshotHistory.Point? {
        model.points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    /// Fits the data with some room above and below, rather than starting at zero,
    /// so small changes stay visible.
    private func yDomain(_ points: [SnapshotHistory.Point]) -> ClosedRange<Int> {
        let values = points.map(\.followers)
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let padding = max(2, (high - low) / 5)
        return max(0, low - padding)...(high + padding)
    }

    private func dateFormat(_ points: [SnapshotHistory.Point]) -> Date.FormatStyle {
        let span = (points.last?.date ?? .now).timeIntervalSince(points.first?.date ?? .now)
        return span > 300 * 86_400
            ? .dateTime.month(.abbreviated).year(.twoDigits)
            : .dateTime.month(.abbreviated).day()
    }
}

// MARK: - Shared

extension View {
    /// The rounded panel used for dashboard sections.
    func card() -> some View {
        background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.separator.opacity(0.6), lineWidth: 1)
            }
    }

    /// The page's title is already shown large in its header, so don't repeat it in the toolbar.
    @ViewBuilder func hidingToolbarTitle() -> some View {
        if #available(macOS 15, *) {
            toolbar(removing: .title)
        } else {
            self
        }
    }
}
