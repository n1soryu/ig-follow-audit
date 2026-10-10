#if DEBUG
import AppKit
import FollowAuditCore

/// Development aid for checking the UI without Screen Recording permission.
///
///     IGFA_SNAPSHOT=/tmp/shots IGFA_EXPORT=/path/to/export swift run
///
/// renders the window to PNGs (light and dark) and quits. `IGFA_EXPORT` can
/// list several exports separated by `:`, imported oldest first, to fill the
/// history. These runs use a temporary data folder, never your saved data.
/// Debug builds only.
enum DebugSnapshot {
    @MainActor static func runIfRequested(model: AppModel) {
        let env = ProcessInfo.processInfo.environment
        if env["IGFA_SCROLLTEST"] != nil, let export = env["IGFA_EXPORT"] {
            scrollTest(model: model, export: URL(fileURLWithPath: export))
            return
        }
        guard let outDir = env["IGFA_SNAPSHOT"] else { return }

        Task { @MainActor in
            // Unbundled debug builds have no icon; borrow the rendered one.
            if let icon = NSImage(contentsOfFile: "Resources/Icon/AppIcon-1024.png") {
                NSApp.applicationIconImage = icon
            }
            try? await Task.sleep(for: .seconds(0.5))
            // IGFA_WINDOW=1000x1400 renders at a custom size, e.g. to see below the fold.
            if let size = env["IGFA_WINDOW"]?.split(separator: "x").compactMap({ Double($0) }), size.count == 2 {
                NSApp.windows.first(where: \.isVisible)?.setContentSize(NSSize(width: size[0], height: size[1]))
            }
            try? await Task.sleep(for: .seconds(1.5))
            await capture(model: model, to: "\(outDir)/welcome")

            if let exports = env["IGFA_EXPORT"] {
                for export in exports.split(separator: ":") {
                    model.open(URL(fileURLWithPath: String(export)))
                    while model.isLoading { try? await Task.sleep(for: .milliseconds(100)) }
                    model.message = nil
                }
                try? await Task.sleep(for: .seconds(1))
                await capture(model: model, to: "\(outDir)/overview")

                model.page = .list(.notFollowingBack)
                try? await Task.sleep(for: .seconds(0.5))
                model.setDone(true, for: model.currentAccounts.prefix(3).map(\.username))
                try? await Task.sleep(for: .seconds(0.5))
                await capture(model: model, to: "\(outDir)/results")
                model.setDone(false, for: model.currentAccounts.prefix(3).map(\.username))

                model.page = .snapshots
                try? await Task.sleep(for: .seconds(0.5))
                await capture(model: model, to: "\(outDir)/snapshots")
            }
            NSApp.terminate(nil)
        }
    }

    /// `IGFA_SCROLLTEST=1 IGFA_EXPORT=…`: loads the export and scrolls every list top to bottom.
    @MainActor private static func scrollTest(model: AppModel, export: URL) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            log("opening export")
            model.open(export)
            try? await Task.sleep(for: .milliseconds(100))
            while model.isLoading { try? await Task.sleep(for: .milliseconds(100)) }
            guard model.audit != nil else { log("load failed: \(model.message?.text ?? "unknown")"); exit(1) }
            model.message = nil
            log("loaded")

            for kind in AppModel.ListKind.allCases {
                log("switching to \(kind.title)")
                model.page = .list(kind)
                try? await Task.sleep(for: .seconds(0.5))
                guard let table = NSApp.windows.first(where: \.isVisible)?.contentView.flatMap(findTable) else {
                    log("no table found"); exit(1)
                }
                log("scrolling \(table.numberOfRows) rows")
                var row = 0
                while row < table.numberOfRows {
                    table.scrollRowToVisible(row)
                    row += 25
                    try? await Task.sleep(for: .milliseconds(15))
                }
                table.scrollRowToVisible(0)

                // Things people do mid-scroll: tick rows off, search, re-sort.
                let names = model.currentAccounts.prefix(40).map(\.username)
                log("action: tick 40 done")
                model.setDone(true, for: names)
                try? await Task.sleep(for: .milliseconds(200))
                for query in ["a", "ab", "", "zz", ""] {
                    log("action: search '\(query)'")
                    model.search = query
                    try? await Task.sleep(for: .milliseconds(200))
                    log("action: scroll to end")
                    table.scrollRowToVisible(max(0, table.numberOfRows - 1))
                }
                log("action: sort by name")
                model.sortOrder = [KeyPathComparator(\Account.username)]
                try? await Task.sleep(for: .milliseconds(200))
                table.scrollRowToVisible(table.numberOfRows / 2)
                log("action: sort by date")
                model.sortOrder = [KeyPathComparator(\Account.sortDate, order: .reverse)]
                try? await Task.sleep(for: .milliseconds(200))
                log("action: untick")
                model.setDone(false, for: names)
                try? await Task.sleep(for: .milliseconds(200))
            }
            // Simulate clicking the sorted column's header, which reverses the sort.
            if let table = NSApp.windows.first(where: \.isVisible)?.contentView.flatMap(findTable) {
                let before = model.sortOrder.first?.order
                table.scrollRowToVisible(table.numberOfRows - 1)
                table.sortDescriptors = table.sortDescriptors.compactMap { $0.reversedSortDescriptor as? NSSortDescriptor }
                try? await Task.sleep(for: .milliseconds(300))
                let after = model.sortOrder.first?.order
                log("header click: sort \(String(describing: before)) -> \(String(describing: after))")
                if before == after { log("header sort FAILED"); exit(1) }
            }
            log("scroll test passed")
            NSApp.terminate(nil)
        }
    }

    /// Unbuffered, so it interleaves correctly with AppKit's own log lines.
    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("[scrolltest] \(message)\n".utf8))
    }

    @MainActor private static func findTable(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for subview in view.subviews {
            if let table = findTable(in: subview) { return table }
        }
        return nil
    }

    @MainActor private static func capture(model: AppModel, to basePath: String) async {
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            NSApp.appearance = NSAppearance(named: appearance)
            try? await Task.sleep(for: .seconds(0.6))
            guard let window = NSApp.windows.first(where: \.isVisible),
                  let view = window.contentView?.superview ?? window.contentView else { continue }
            view.layoutSubtreeIfNeeded()
            view.display()
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: "\(basePath)-\(suffix).png"))
        }
        NSApp.appearance = nil
    }
}
#endif
