import SwiftUI
import SwiftData

struct InvoiceGeneratorView: View {
    let clientID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var showShareSheet = false
    @State private var generatedPDFURL: URL?
    @State private var toast = ToastState()

    private var client: Client? {
        modelContext.model(for: clientID) as? Client
    }

    private var filteredTransactions: [Transaction] {
        guard let client else { return [] }
        return (client.transactions ?? [])
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date < $1.date }
    }

    private var total: Double {
        filteredTransactions.reduce(0) { result, txn in
            txn.type == .income ? result + txn.amount : result - txn.amount
        }
    }

    var body: some View {
        let txns = filteredTransactions
        let txnTotal = total
        NavigationStack {
            Form {
                Section("Date Range") {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }

                Section("Preview (\(txns.count) transactions)") {
                    if txns.isEmpty {
                        Text("No transactions in this period")
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
                                    .foregroundStyle(txn.type == .income ? .green : .red)
                            }
                        }
                        HStack {
                            Text("Total")
                                .font(.headline)
                            Spacer()
                            Text(txnTotal.asCurrency)
                                .font(.headline)
                                .foregroundStyle(txnTotal >= 0 ? .green : .red)
                        }
                    }
                }

                Section {
                    Button {
                        generateAndShare()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Generate & Share Invoice", systemImage: "doc.text.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(txns.isEmpty)
                }
            }
            .navigationTitle("Generate Invoice")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = generatedPDFURL {
                    ShareSheet(items: [url])
                }
            }
            .toast(toast)
        }
    }

    private func generateAndShare() {
        guard let client else { return }
        let txns = filteredTransactions
        let txnTotal = total

        let lineItems = txns.map { txn in
            InvoicePDFService.LineItem(
                date: txn.date,
                description: txn.memo.isEmpty ? txn.category.displayName : txn.memo,
                category: txn.category.displayName,
                amount: txn.type == .income ? txn.amount : -txn.amount
            )
        }

        let pdfData = InvoicePDFService.generatePDF(
            clientName: client.fullName,
            startDate: startDate,
            endDate: endDate,
            lineItems: lineItems,
            total: txnTotal
        )

        let invoice = Invoice(
            startDate: startDate,
            endDate: endDate,
            totalAmount: txnTotal,
            createdAt: .now,
            pdfData: pdfData
        )
        invoice.client = client
        modelContext.insert(invoice)

        BarnHubLogger.success("Invoice generated for client=\(client.fullName) transactions=\(txns.count) total=\(txnTotal)")

        let fileName = Invoice.fileName(clientName: client.fullName, startDate: startDate, endDate: endDate)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tempURL)
        } catch {
            BarnHubLogger.error("Failed to write invoice PDF error=\(error.localizedDescription)")
            toast.show(String(localized: "Failed to save invoice"), isError: true)
            return
        }
        generatedPDFURL = tempURL
        showShareSheet = true
    }
}
