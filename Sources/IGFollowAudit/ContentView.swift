import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Group {
            if !model.hasLoaded {
                Color.clear
            } else if model.history.latest != nil {
                ResultsView()
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 760, minHeight: 540)
        .tint(Theme.accent)
        .overlay {
            if model.isLoading {
                ProgressView("Reading…")
                    .controlSize(.large)
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
            }
        }
        // One importer for both kinds of file: two .fileImporter modifiers in
        // the same hierarchy don't reliably both work.
        .fileImporter(
            isPresented: $model.isImporterPresented,
            allowedContentTypes: model.importerMode == .export ? [.zip, .folder] : [.json]
        ) { result in
            guard case .success(let url) = result else { return }
            switch model.importerMode {
            case .export: model.open(url)
            case .history: model.restoreHistory(from: url)
            }
        }
        .fileExporter(
            isPresented: $model.isExportingHistory,
            document: model.historyDocument,
            contentType: .json,
            defaultFilename: model.backupFileName
        ) { _ in
            model.historyDocument = nil
        }
        .sheet(isPresented: $model.isShowingExportSteps) {
            ExportStepsSheet()
        }
        .alert(
            model.message?.title ?? "",
            isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } }),
            presenting: model.message
        ) { _ in
            Button("OK") {}
        } message: { message in
            Text(message.text)
        }
    }
}

/// How to request an export from Instagram, as a sheet.
private struct ExportStepsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Get a New Export")
                    .font(.title2.weight(.bold))
                Text("Instagram can take from a few minutes to a few hours to email it to you.")
                    .foregroundStyle(.secondary)
            }
            ExportSteps()
            HStack {
                Spacer()
                Button("Done") { model.isShowingExportSteps = false }
                    .keyboardShortcut(.cancelAction)
                Button("Import Export…") {
                    model.isShowingExportSteps = false
                    model.presentExportImporter()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 680)
    }
}
