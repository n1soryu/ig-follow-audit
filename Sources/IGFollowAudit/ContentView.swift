import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Group {
            if model.audit != nil {
                ResultsView()
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .tint(Theme.accent)
        .overlay {
            if model.isLoading {
                ProgressView("Reading export…")
                    .controlSize(.large)
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
            }
        }
        .fileImporter(isPresented: $model.isImporterPresented, allowedContentTypes: [.zip, .folder]) { result in
            if case .success(let url) = result {
                model.open(url)
            }
        }
        .alert(
            "Couldn't Open Export",
            isPresented: Binding(get: { model.loadError != nil }, set: { if !$0 { model.loadError = nil } }),
            presenting: model.loadError
        ) { _ in
            Button("OK") {}
        } message: { error in
            Text([error.message, error.suggestion].compactMap { $0 }.joined(separator: "\n\n"))
        }
    }
}
