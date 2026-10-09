import AppKit
import SwiftUI

@main
struct IGFollowAuditApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let model = AppModel()

    init() {
        #if DEBUG
        DebugSnapshot.runIfRequested(model: model)
        #endif
    }

    var body: some Scene {
        Window("IG Follow Audit", id: "main") {
            ContentView()
                .environment(model)
        }
        .defaultSize(width: 980, height: 740)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Export…") { model.isImporterPresented = true }
                    .keyboardShortcut("o")
                Button("Close Export") { model.close() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                    .disabled(model.audit == nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Lets `swift run` show a normal Dock app too, not just the bundled .app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
