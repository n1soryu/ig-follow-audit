import AppKit
import FollowAuditCore
import SwiftUI

/// Every saved snapshot, with dates to correct, backups, and deleting data.
struct SnapshotsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            header
            table
            footer
        }
        .navigationTitle("Snapshots")
        .hidingToolbarTitle()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Back Up History", systemImage: "externaldrive") { model.backUpHistory() }
                    .help("Save every snapshot and tick to one backup file (⇧⌘S)")
                Button("Import Export", systemImage: "square.and.arrow.down") { model.presentExportImporter() }
                    .help("Import a new Instagram export (⌘O)")
            }
        }
        .confirmationDialog(
            "Delete this snapshot?",
            isPresented: Binding(get: { model.snapshotPendingDeletion != nil }, set: { if !$0 { model.snapshotPendingDeletion = nil } }),
            presenting: model.snapshotPendingDeletion
        ) { snapshot in
            Button("Delete Snapshot", role: .destructive) { model.delete(snapshot) }
        } message: { snapshot in
            Text("The data from \(snapshot.capturedAt.formatted(date: .long, time: .omitted)) will be removed from your history. Unless you still have that export or a backup, this can't be undone.")
        }
        .confirmationDialog("Delete all saved data?", isPresented: $model.isConfirmingDeleteAll) {
            Button("Delete All Data", role: .destructive) { model.deleteAllData() }
        } message: {
            Text("Every snapshot and ticked-off account will be removed from this Mac. Back up your history first if you might want it later.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Snapshots")
                .font(.system(size: 26, weight: .bold))
            Text("Each export you've imported. The app keeps its own copy, so you can delete the .zip files. If a date is wrong, click it to change it.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    /// A plain grid rather than a `Table`: there are only ever a few dozen
    /// snapshots, so AppKit's row recycling buys nothing here.
    private var table: some View {
        let points = Dictionary(uniqueKeysWithValues: model.points.map { ($0.id, $0) })

        return ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 0) {
                GridRow {
                    Text("Data From")
                    Text("Followers").gridColumnAlignment(.trailing)
                    Text("Following").gridColumnAlignment(.trailing)
                    Text("Mutuals").gridColumnAlignment(.trailing)
                    Text("Imported")
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

                ForEach(model.history.snapshots.reversed()) { snapshot in
                    Divider()
                    row(snapshot, mutuals: points[snapshot.id]?.mutuals ?? 0)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    private func row(_ snapshot: Snapshot, mutuals: Int) -> some View {
        let isViewed = snapshot.id == model.currentSnapshot?.id

        return GridRow {
            DatePicker(
                "Data from",
                selection: Binding(get: { snapshot.capturedAt }, set: { model.setCaptureDate($0, for: snapshot.id) }),
                in: ...Date.now,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.field)
            .fixedSize()
            .help("When Instagram produced this export")

            Text(snapshot.followers.count.formatted()).monospacedDigit()
            Text(snapshot.following.count.formatted()).monospacedDigit()
            Text(mutuals.formatted()).monospacedDigit()
            Text(snapshot.importedAt.formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Button(isViewed ? "Viewing" : "View") {
                    model.viewedSnapshotID = snapshot.id == model.history.latest?.id ? nil : snapshot.id
                    model.page = .overview
                }
                .disabled(isViewed)
                Button {
                    model.snapshotPendingDeletion = snapshot
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete this snapshot")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.unreadableFiles.isEmpty {
                Label(
                    "\(model.unreadableFiles.count) saved snapshot file\(model.unreadableFiles.count == 1 ? "" : "s") couldn't be read: damaged, or saved by a newer version of the app. They've been left as they are.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label("Stored only on this Mac. Nothing is uploaded.", systemImage: "lock.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([model.store.directory])
                }
                .buttonStyle(.link)
                .font(.callout)
                Spacer()
                Button("Restore History…") { model.presentHistoryImporter() }
                Button("Delete All Data…", role: .destructive) { model.isConfirmingDeleteAll = true }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}
