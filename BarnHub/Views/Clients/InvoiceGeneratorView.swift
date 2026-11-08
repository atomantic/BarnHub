import SwiftUI
import SwiftData

struct InvoiceGeneratorView: View {
    let clientID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var sharedPDF: SharedFile?
    /// A PDF is being drawn in the background; the button stays disabled until it's ready.
    @State private var isGenerating = false
    @State private var toast = ToastState()

    private var client: Client? {
        modelContext.existingModel(for: clientID)
    }

    /// Unpaid charges in the picked days, and Total Due (see `InvoiceBuilder`).
    private var invoice: InvoiceBuilder {
        InvoiceBuilder(transactions: client?.transactions ?? [], from: startDate, through: endDate)
    }

    var body: some View {
        let built = invoice
        let txns = built.charges
        NavigationStack {
            Form {
                Section("Date Range") {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }

                Section {
                    if txns.isEmpty {
                        Text("No unpaid charges in this period")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(txns, id: \.persistentModelID) { txn in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(txn.category.displayName)
                                        .font(.subheadline)
                                    Text(txn.date.shortFormatted)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(txn.amount.asCurrency)
                                    .font(.subheadline)
                                    .monospacedDigit()
                            }
                        }
                        HStack {
                            Text("Total Due")
                                .font(.headline)
                            Spacer()
                            Text(built.totalDue.asCurrency)
                                .font(.headline)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text(appLocalized("Preview (\(txns.count) transactions)", comment: "Invoice generator section header: number of unpaid charges on the invoice"))
                } footer: {
                    if built.excludedCount > 0 {
                        Text(appLocalized("\(built.excludedCount) paid or expense transactions not included", comment: "Invoice generator footer: transactions in the date range left off the invoice because they are paid or are expenses"))
                    }
                }

                Section {
                    Button {
                        generateAndShare()
                    } label: {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Label("Generate & Share Invoice", systemImage: "doc.text.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(txns.isEmpty || isGenerating)
                }
            }
            .navigationTitle("Generate Invoice")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .shareSheet($sharedPDF)
            .toast(toast)
        }
    }

    private func generateAndShare() {
        guard let client, !isGenerating else { return }
        let built = invoice
        let txnTotal = built.totalDue
        let lineItemCount = built.lineItems.count
        let excludedCount = built.excludedCount
        let start = startDate
        let end = endDate
        let document = InvoicePDFService.document(
            clientName: client.fullName,
            startDate: start,
            endDate: end,
            lineItems: built.lineItems,
            total: txnTotal
        )
        let fileName = Invoice.fileName(clientName: client.fullName, startDate: start, endDate: end)

        isGenerating = true
        Task {
            defer { isGenerating = false }
            // Drawing the PDF and writing the share file can take a moment on a
            // long invoice, so keep both off the main actor.
            let result = await Task.detached(priority: .userInitiated) {
                let pdfData = InvoicePDFService.render(document)
                return (pdfData, Result { try ShareTempFiles.write(pdfData, fileName: fileName, fileExtension: "pdf") })
            }.value
            let (pdfData, written) = result

            let invoice = Invoice(
                startDate: start,
                endDate: end,
                totalAmount: txnTotal,
                createdAt: .now,
                pdfData: pdfData
            )
            invoice.client = client
            modelContext.insert(invoice)

            BarnHubLogger.success("Invoice generated transactions=\(lineItemCount) excluded=\(excludedCount)")

            switch written {
            case .success(let tempURL):
                sharedPDF = SharedFile(url: tempURL)
            case .failure(let error):
                BarnHubLogger.error("Failed to write invoice PDF error=\(error.localizedDescription)")
                toast.show(appLocalized("Failed to save invoice"), isError: true)
            }
        }
    }
}
