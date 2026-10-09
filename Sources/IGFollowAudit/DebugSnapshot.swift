#if DEBUG
import AppKit

/// Development aid for checking the UI without Screen Recording permission.
///
///     IGFA_SNAPSHOT=/tmp/shots IGFA_EXPORT=/path/to/export swift run
///
/// renders the window to PNGs (light and dark) and quits. Debug builds only.
enum DebugSnapshot {
    @MainActor static func runIfRequested(model: AppModel) {
        let env = ProcessInfo.processInfo.environment
        guard let outDir = env["IGFA_SNAPSHOT"] else { return }

        Task { @MainActor in
            // Unbundled debug builds have no icon; borrow the rendered one.
            if let icon = NSImage(contentsOfFile: "Resources/Icon/AppIcon-1024.png") {
                NSApp.applicationIconImage = icon
            }
            try? await Task.sleep(for: .seconds(1.5))
            await capture(model: model, to: "\(outDir)/welcome")

            if let export = env["IGFA_EXPORT"] {
                model.open(URL(fileURLWithPath: export))
                try? await Task.sleep(for: .seconds(1.5))
                model.setDone(true, for: model.currentAccounts.prefix(3).map(\.username))
                try? await Task.sleep(for: .seconds(0.5))
                await capture(model: model, to: "\(outDir)/results")
                model.setDone(false, for: model.currentAccounts.prefix(3).map(\.username))
            }
            NSApp.terminate(nil)
        }
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
