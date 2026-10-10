import AppKit
import SwiftUI

struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    private var isTargeted: Bool { model.isDropTargeted }

    var body: some View {
        ZStack {
            Backdrop()
            // Centre the content when it fits, scroll when the window is short.
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
    }

    private var content: some View {
        VStack(spacing: 28) {
            hero
            dropZone
            steps
            privacyBadge
            restoreLink
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 32)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pieces

    private var hero: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("IG Follow Audit")
                .font(.system(size: 34, weight: .bold))
            Text("Keep track of who follows you, privately, right on your Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private var dropZone: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.gradient)
                    .opacity(isTargeted ? 0.25 : 0.14)
                    .frame(width: 76, height: 76)
                Image(systemName: isTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Theme.gradient)
            }
            VStack(spacing: 4) {
                Text(isTargeted ? "Release to open" : "Drop your Instagram export here")
                    .font(.title2.weight(.semibold))
                Text("The .zip from Instagram, or the folder you extracted it to.")
                    .foregroundStyle(.secondary)
            }
            Button {
                model.presentExportImporter()
            } label: {
                Label("Choose File…", systemImage: "folder")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    isTargeted ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.separator),
                    style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 1.5, dash: isTargeted ? [] : [7, 5])
                )
        }
        .shadow(color: .black.opacity(isTargeted ? 0.12 : 0.06), radius: isTargeted ? 24 : 14, y: 6)
        .scaleEffect(isTargeted ? 1.015 : 1)
        .animation(.spring(duration: 0.3), value: isTargeted)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.open(url)
            return true
        } isTargeted: {
            model.isDropTargeted = $0
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to get your export")
                .font(.headline)
                .foregroundStyle(.secondary)
            ExportSteps()
        }
    }

    private var restoreLink: some View {
        Button("Moving from another Mac? Restore a history backup…") {
            model.presentHistoryImporter()
        }
        .buttonStyle(.link)
        .font(.callout)
    }

    private var privacyBadge: some View {
        Label("Private by design: no network access. Your history is stored only on this Mac.", systemImage: "lock.shield.fill")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
    }
}

/// The four steps for requesting an export from Instagram.
struct ExportSteps: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            StepCard(number: 1, systemImage: "gearshape", title: "Open Settings",
                     detail: "In Instagram: Accounts Center → Your information and permissions.")
            StepCard(number: 2, systemImage: "arrow.down.circle", title: "Download your info",
                     detail: "Choose Some of your information → Followers and following.")
            StepCard(number: 3, systemImage: "curlybraces", title: "Pick JSON",
                     detail: "Download to device, Format: JSON, Date range: All time.")
            StepCard(number: 4, systemImage: "envelope", title: "Check your email",
                     detail: "Download the .zip Instagram sends you and import it here.")
        }
    }
}

private struct StepCard: View {
    let number: Int
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Theme.gradient, in: Circle())
                Spacer()
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
