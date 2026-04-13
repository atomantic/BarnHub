import SwiftUI
import SwiftData

struct InvoiceHistoryView: View {
    let clientID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    @State private var showShareSheet = false
    @State private var selectedPDFURL: URL?
    @State private var toast = ToastState()

    private var client: Client? {
        modelContext.model(for: clientID) as? Client
    }

    private var invoices: [Invoice] {
        (client?.invoices ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if invoices.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Invoices",
                    subtitle: "Generate an invoice from the client detail page."
                )
            } else {
                List {
                ForEach(invoices, id: \.persistentModelID) { invoice in
                    Button {
                        reshareInvoice(invoice)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(invoice.startDate.shortFormatted) – \(invoice.endDate.shortFormatted)")
                                    .font(.subheadline.weight(.medium))
                                Text("Created \(invoice.createdAt.shortFormatted)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(invoice.totalAmount.asCurrency)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(invoice.totalAmount >= 0 ? .green : .red)
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteInvoices)
                }
            }
        }
        .navigationTitle("Invoice History")
        .inlineNavTitle()
        .toast(toast)
        .sheet(isPresented: $showShareSheet) {
            if let url = selectedPDFURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func reshareInvoice(_ invoice: Invoice) {
        guard let data = invoice.pdfData else { return }
        let fileName = Invoice.fileName(clientName: client?.fullName ?? "Client", startDate: invoice.startDate, endDate: invoice.endDate)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
        } catch {
            BarnHubLogger.error("Failed to write invoice PDF error=\(error.localizedDescription)")
            toast.show(appLocalized("Failed to load invoice"), isError: true)
            return
        }
        selectedPDFURL = tempURL
        showShareSheet = true
    }

    private func deleteInvoices(at offsets: IndexSet) {
        for index in offsets {
            let invoice = invoices[index]
            BarnHubLogger.info("Deleting invoice createdAt=\(invoice.createdAt.shortFormatted)")
            modelContext.delete(invoice)
        }
        modelContext.saveWithLogging()
    }
}
