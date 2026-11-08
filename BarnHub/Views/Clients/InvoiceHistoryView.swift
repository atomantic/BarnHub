import SwiftUI
import SwiftData

struct InvoiceHistoryView: View {
    let clientID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    @State private var sharedPDF: SharedFile?
    @State private var toast = ToastState()

    private var client: Client? {
        modelContext.existingModel(for: clientID)
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
                    // Not .buttonStyle(.plain): in a Mac list a plain button's click
                    // only selects the row, so the invoice never opened there.
                    .foregroundStyle(.primary)
                }
                .onDelete(perform: deleteInvoices)
                }
            }
        }
        .navigationTitle("Invoice History")
        .inlineNavTitle()
        .toast(toast)
        .shareSheet($sharedPDF)
    }

    private func reshareInvoice(_ invoice: Invoice) {
        guard let data = invoice.pdfData else { return }
        let fileName = Invoice.fileName(clientName: client?.fullName ?? "Client", startDate: invoice.startDate, endDate: invoice.endDate)
        let tempURL: URL
        do {
            tempURL = try ShareTempFiles.write(data, fileName: fileName, fileExtension: "pdf")
        } catch {
            BarnHubLogger.error("Failed to write invoice PDF error=\(error.localizedDescription)")
            toast.show(appLocalized("Failed to load invoice"), isError: true)
            return
        }
        sharedPDF = SharedFile(url: tempURL)
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
