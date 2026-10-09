import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Group {
            if let audit = model.audit {
                ResultsView(audit: audit)
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .overlay {
            if model.isLoading {
                ProgressView("Reading export…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
