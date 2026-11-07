#if os(iOS)
import MessageUI
#elseif os(macOS)
import AppKit
#endif
import SwiftData
import SwiftUI

/// Lets the user describe a problem and email it to support with a
/// non-personal diagnostics snapshot attached, so support doesn't have to ask
/// for app version, device, sync state, and recent errors.
struct BugReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(StoreService.self) private var storeService
    @Environment(SyncMonitor.self) private var syncMonitor
    @Environment(AppearanceManager.self) private var appearanceManager

    @State private var problemDescription = ""
    @State private var steps = ""
    @State private var includeDiagnostics = true
    @State private var diagnostics: AppDiagnostics?
    @State private var showingMailComposer = false
    @State private var toast = ToastState()

    private var attachedDiagnostics: AppDiagnostics? {
        includeDiagnostics ? diagnostics : nil
    }

    private var canSend: Bool {
        !problemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $problemDescription)
                        .frame(minHeight: 100)
                        .accessibilityLabel(Text("What happened?"))
                } header: {
                    Text("What happened?")
                } footer: {
                    Text("Describe what you expected and what happened instead.")
                }

                Section {
                    TextEditor(text: $steps)
                        .frame(minHeight: 80)
                        .accessibilityLabel(Text("Steps to reproduce (optional)"))
                } header: {
                    Text("Steps to reproduce (optional)")
                }

                Section {
                    Toggle("Include diagnostic info", isOn: $includeDiagnostics)
                    if includeDiagnostics {
                        DisclosureGroup("Preview diagnostic info") {
                            if let diagnostics {
                                Text(diagnostics.formatted)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ProgressView()
                            }
                        }
                    }
                } footer: {
                    Text("Diagnostic info includes the app version, device model, settings, iCloud sync status, record counts, and recent error messages. It never includes names, notes, contacts, amounts, or anything else you've entered.")
                }

                Section {
                    Button {
                        send()
                    } label: {
                        Label("Send Report", systemImage: "paperplane")
                    }
                    .disabled(!canSend)

                    Button {
                        copyReport()
                    } label: {
                        Label("Copy Report", systemImage: "doc.on.doc")
                    }
                    .disabled(!canSend)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Report a Bug")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                diagnostics = await DiagnosticsCollector.collect(
                    context: modelContext,
                    isPro: storeService.isPro,
                    hasLifetime: storeService.hasLifetime,
                    syncMonitor: syncMonitor,
                    appearance: appearanceManager.mode
                )
            }
            #if os(iOS)
            .sheet(isPresented: $showingMailComposer) {
                MailComposer(
                    recipient: BugReport.supportEmail,
                    subject: BugReport.subject(diagnostics: attachedDiagnostics),
                    body: reportBody,
                    onDismiss: { showingMailComposer = false }
                )
                .ignoresSafeArea()
            }
            #endif
            .toast(toast)
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    private var reportBody: String {
        BugReport.body(description: problemDescription, steps: steps, diagnostics: attachedDiagnostics)
    }

    private func send() {
        #if os(iOS)
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
            return
        }
        #endif
        guard let url = BugReport.mailtoURL(
            description: problemDescription,
            steps: steps,
            diagnostics: attachedDiagnostics
        ) else {
            copyReport()
            return
        }
        openURL(url) { accepted in
            if !accepted { copyReport() }
        }
    }

    private func copyReport() {
        let text = "\(BugReport.subject(diagnostics: attachedDiagnostics))\n\n\(reportBody)"
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        BarnHubLogger.info("Bug report copied to clipboard")
        toast.show(appLocalized(
            "Report copied. Paste it into an email to \(BugReport.supportEmail).",
            comment: "Toast after copying a bug report; the argument is the support email address"
        ))
    }
}

#if DEBUG
#Preview {
    BugReportView()
        .environment(StoreService())
        .environment(SyncMonitor())
        .environment(AppearanceManager())
        .modelContainer(PreviewSampleData.previewContainer)
}
#endif
