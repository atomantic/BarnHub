import SwiftUI
import QuickLook

#if os(iOS)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#else

struct ShareSheet: View {
    let items: [Any]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Export Complete")
                .font(.headline)
            if let url = items.first as? URL {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.plain)
        }
        .padding(24)
        .frame(minWidth: 260)
    }
}

#endif

// MARK: - Document Presentation

/// A temp file to show in a share sheet. The sheet is presented by item, so
/// its content always reads the URL it was opened for. Presenting with a Bool
/// and a separate optional URL can build the sheet before the URL lands, and
/// the sheet then opens blank.
struct SharedFile: Identifiable {
    let url: URL
    var id: URL { url }
}

extension View {
    /// Shows the share sheet for `file` and removes its temp file once the
    /// sheet closes.
    func shareSheet(_ file: Binding<SharedFile?>) -> some View {
        sheet(item: file) { file in
            ShareSheet(items: [file.url])
        }
        .onChange(of: file.wrappedValue?.url) { old, _ in ShareTempFiles.cleanUp(old) }
        #if DEBUG
        // iPad shows the system share sheet out of process, where UI tests
        // can't see it; this marks that one is up (ScreenWalkTests).
        .background {
            if file.wrappedValue != nil {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("share_sheet_presented")
            }
        }
        #endif
    }

    /// Quick Look for tapping a stored document (photo or PDF) and a share
    /// sheet for its Share action. Both take temp files from `ShareTempFiles`,
    /// and each file is removed once its preview or sheet closes.
    func documentPresentation(preview: Binding<URL?>, share: Binding<SharedFile?>) -> some View {
        quickLookPreview(preview)
            .onChange(of: preview.wrappedValue) { old, _ in ShareTempFiles.cleanUp(old) }
            #if DEBUG
            // The Mac's Quick Look panel runs out of process, where UI tests
            // can't see it; this marks that a preview is up (ScreenWalkTests).
            .background {
                if preview.wrappedValue != nil {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityIdentifier("quick_look_presented")
                }
            }
            #endif
            .shareSheet(share)
    }
}
