import SwiftUI
import SwiftData

struct TransactionEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var storeService

    @Query private var clients: [Client]

    let transactionID: PersistentIdentifier?

    @State private var amount: Double = 0
    @State private var date: Date = .now
    @State private var memo: String = ""
    @State private var category: TransactionCategory = .other
    @State private var type: TransactionType = .expense
    @State private var isPaid: Bool = false
    @State private var selectedClientID: PersistentIdentifier?

    @State private var toast = ToastState()

    private var isNew: Bool { transactionID == nil }
    private var existingTransaction: Transaction? {
        guard let id = transactionID else { return nil }
        return modelContext.model(for: id) as? Transaction
    }

    var body: some View {
        Form {
            Section("Details") {
                CurrencyField(label: "Amount", value: $amount)

                DatePicker("Date", selection: $date, displayedComponents: .date)

                TextField("Memo", text: $memo)

                Picker("Category", selection: $category) {
                    ForEach(TransactionCategory.allCases) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }

                Picker("Type", selection: $type) {
                    ForEach(TransactionType.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }

                Toggle("Paid", isOn: $isPaid)
            }

            if FeatureGate.canLinkClientToTransaction(storeService.isPro) {
                Section("Client") {
                    Picker("Assign Client", selection: $selectedClientID) {
                        Text("None").tag(nil as PersistentIdentifier?)
                        ForEach(clients) { client in
                            Text(client.fullName).tag(client.persistentModelID as PersistentIdentifier?)
                        }
                    }
                }
            }
        }
        .navigationTitle(isNew ? "New Transaction" : "Edit Transaction")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    save()
                }
            }
        }
        .task { loadExisting() }
        .toast(toast)
    }

    private func loadExisting() {
        guard let txn = existingTransaction else { return }
        amount = txn.amount
        date = txn.date
        memo = txn.memo
        category = txn.category
        type = txn.type
        isPaid = txn.isPaid
        selectedClientID = txn.client?.persistentModelID
    }

    private func save() {
        let txn: Transaction
        if let existing = existingTransaction {
            txn = existing
        } else {
            txn = Transaction()
            modelContext.insert(txn)
        }

        txn.amount = amount
        txn.date = date
        txn.memo = memo
        txn.category = category
        txn.type = type
        txn.isPaid = isPaid

        if let clientID = selectedClientID {
            txn.client = modelContext.model(for: clientID) as? Client
        } else {
            txn.client = nil
        }

        modelContext.saveWithLogging()
        toast.show(isNew ? "Transaction added" : "Transaction updated")

        Task {
            try? await Task.sleep(for: .seconds(0.5))
            dismiss()
        }
    }
}
