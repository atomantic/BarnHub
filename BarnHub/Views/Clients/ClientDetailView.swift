import SwiftUI
import SwiftData

struct ClientDetailView: View {
    let clientID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(StoreService.self) private var storeService
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var toast = ToastState()
    @State private var showInvoiceGenerator = false
    @State private var showContractGenerator = false

    private var client: Client? {
        modelContext.model(for: clientID) as? Client
    }

    private var sortedRecentTransactions: [Transaction] {
        Array((client?.transactions ?? []).sorted { $0.date > $1.date }.prefix(5))
    }

    var body: some View {
        Group {
            if let client {
                clientContent(client)
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Client Not Found",
                    subtitle: "This client may have been deleted."
                )
            }
        }
        .overlay {
            ConfirmationDialog(
                isPresented: $showDeleteConfirmation,
                title: "Delete Client",
                message: "Are you sure you want to delete this client? All associated transactions will also be removed.",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: deleteClient
            )
        }
        .toast(toast)
    }

    @ViewBuilder
    private func clientContent(_ client: Client) -> some View {
        let recentTransactions = sortedRecentTransactions
        let allTransactionsCount = client.transactions?.count ?? 0
        List {
            Section("Contact Info") {
                if !client.email.isEmpty {
                    LabeledContent("Email", value: client.email)
                }
                if !client.phone.isEmpty {
                    LabeledContent("Phone", value: client.phone)
                }
                LabeledContent("Status", value: client.isActive ? "Active" : "Inactive")
            }

            Section("Emergency Contact") {
                if client.emergencyContact.isEmpty && client.emergencyPhone.isEmpty {
                    Text("No emergency contact on file")
                        .foregroundStyle(.secondary)
                } else {
                    if !client.emergencyContact.isEmpty {
                        LabeledContent("Name", value: client.emergencyContact)
                    }
                    if !client.emergencyPhone.isEmpty {
                        LabeledContent("Phone", value: client.emergencyPhone)
                    }
                }
            }

            if !client.notes.isEmpty {
                Section("Notes") {
                    Text(client.notes)
                }
            }

            Section {
                let horses = (client.horses ?? []).sorted { $0.name < $1.name }
                if horses.isEmpty {
                    Text("No assigned horses")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(horses, id: \.persistentModelID) { horse in
                        NavigationLink(value: HorseRoute.detail(horse.persistentModelID)) {
                            HorseRowView(horse: horse)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Horses")
                    Spacer()
                    Button {
                        router.navigate(to: ClientRoute.manageHorses(clientID))
                    } label: {
                        Image(systemName: "pencil.circle")
                    }
                }
            }

            Section {
                if recentTransactions.isEmpty {
                    Text("No transactions")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentTransactions, id: \.persistentModelID) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.category.displayName)
                                    .font(.subheadline)
                                Text(transaction.date.shortFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(transaction.amount.asCurrency)
                                    .font(.subheadline)
                                    .foregroundStyle(transaction.type == .income ? .green : .primary)
                                if transaction.isPaid {
                                    Text("Paid")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Unpaid")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    if allTransactionsCount > 5 {
                        NavigationLink(value: ClientRoute.paymentHistory(clientID)) {
                            Text("View All Transactions")
                                .font(.subheadline)
                                .foregroundStyle(.barnGreen)
                        }
                    }
                }
            } header: {
                Text("Recent Transactions")
            }

            if FeatureGate.canGenerateInvoices(storeService.isPro) {
                Section("Invoices") {
                    Button {
                        showInvoiceGenerator = true
                    } label: {
                        Label("Generate Invoice", systemImage: "doc.text.fill")
                    }
                    NavigationLink(value: ClientRoute.invoiceHistory(clientID)) {
                        Label("Invoice History", systemImage: "clock.arrow.circlepath")
                    }
                }
            }

            if FeatureGate.canGenerateContracts(storeService.isPro) {
                Section("Contracts") {
                    Button {
                        showContractGenerator = true
                    } label: {
                        Label("Generate Contract", systemImage: "doc.richtext.fill")
                    }
                }
            }

            if FeatureGate.canStoreDocuments(storeService.isPro) {
                Section("Documents") {
                    NavigationLink(value: ClientRoute.documents(clientID)) {
                        HStack {
                            Label("Documents", systemImage: "folder.fill")
                            Spacer()
                            let count = client.documents?.count ?? 0
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(client.fullName)
        .inlineNavTitle()
        .sheet(isPresented: $showInvoiceGenerator) {
            InvoiceGeneratorView(clientID: clientID)
        }
        .sheet(isPresented: $showContractGenerator) {
            ContractGeneratorView(clientID: clientID)
        }
        .toolbar {
            ToolbarItem(placement: .trailingBar) {
                Menu {
                    Button {
                        router.navigate(to: ClientRoute.edit(clientID))
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func deleteClient() {
        guard let client else { return }
        BarnHubLogger.info("Deleting client name=\(client.fullName)")
        modelContext.deleteWithLogging(client)
        dismiss()
    }
}
