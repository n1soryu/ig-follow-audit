import SwiftUI

struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    private var isTargeted: Bool { model.isDropTargeted }

    var body: some View {
        VStack(spacing: 24) {
            dropZone
            instructions
            Label("Everything stays on this Mac. The app has no network access.", systemImage: "lock.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text("Drop your Instagram export here")
                .font(.title2.weight(.semibold))
            Text("The .zip file from Instagram, or the folder you extracted it to.")
                .foregroundStyle(.secondary)
            Button("Choose File…") { model.isImporterPresented = true }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isTargeted ? Color.accentColor : .secondary.opacity(0.4),
                              style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.open(url)
            return true
        } isTargeted: {
            model.isDropTargeted = $0
        }
    }

    private var instructions: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                step(1, "In Instagram, go to **Settings → Accounts Center → Your information and permissions → Download your information**.")
                step(2, "Choose **Some of your information** and select only **Followers and following**.")
                step(3, "Pick **Download to device**, with **Format: JSON** and **Date range: All time**.")
                step(4, "When Instagram emails you, download the .zip and drop it above.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Text("How to get your export")
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number).")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
