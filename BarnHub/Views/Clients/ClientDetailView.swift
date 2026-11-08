import SwiftUI
import SwiftData

struct ClientDetailView: View {
    let clientID: PersistentIdentifier
    /// True when shown as the detail pane beside the client list.
    var isEmbedded = false
    /// Called after the client is deleted, so an embedded pane can clear its selection.
    var onDelete: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
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

    // MARK: - Shared sections

    private func contactSection(_ client: Client) -> some View {
        Section("Contact Info") {
            if !client.email.isEmpty {
                LabeledContent("Email", value: client.email)
            }
            if !client.phone.isEmpty {
                LabeledContent("Phone", value: client.phone)
            }
            LabeledContent("Status", value: client.isActive ? "Active" : "Inactive")
        }
    }

    private func emergencySection(_ client: Client) -> some View {
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
    }

    @ViewBuilder
    private func notesSection(_ client: Client) -> some View {
        if !client.notes.isEmpty {
            Section("Notes") {
                Text(client.notes)
            }
        }
    }

    private func horsesSection(_ client: Client) -> some View {
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
    }

    private func transactionsSection(_ client: Client) -> some View {
        let recentTransactions = sortedRecentTransactions
        let allTransactionsCount = client.transactions?.count ?? 0
        return Section {
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
    }

    @ViewBuilder
    private func proSections() -> some View {
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
                .accessibilityIdentifier("generate_contract")
            }
        }

        if FeatureGate.canStoreDocuments(storeService.isPro) {
            Section("Documents") {
                NavigationLink(value: ClientRoute.documents(clientID)) {
                    HStack {
                        Label("Documents", systemImage: "folder.fill")
                        Spacer()
                        let count = client?.documents?.count ?? 0
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

    @ToolbarContentBuilder
    private var clientToolbar: some ToolbarContent {
        // Standalone items (instead of a custom "…" menu) so iPhone Duo can lay
        // them out vertically and fold them into the system overflow menu.
        ToolbarItemGroup(placement: .trailingBar) {
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
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private func clientContent(_ client: Client) -> some View {
        #if os(macOS)
        if isEmbedded {
            macOSClientPaneLayout(client)
        } else {
            macOSClientLayout(client)
        }
        #else
        iOSClientLayout(client)
        #endif
    }

    #if os(iOS)
    private func iOSClientLayout(_ client: Client) -> some View {
        Group {
            if sizeClass == .regular {
                // Same split as macOS: contact + horses left, money + documents right.
                WideColumns {
                    if isEmbedded { DetailPaneHeader(title: client.fullName) }
                    contactSection(client)
                    emergencySection(client)
                    notesSection(client)
                    horsesSection(client)
                } trailing: {
                    transactionsSection(client)
                    proSections()
                }
            } else {
                List {
                    if isEmbedded { DetailPaneHeader(title: client.fullName) }
                    contactSection(client)
                    emergencySection(client)
                    notesSection(client)
                    horsesSection(client)
                    transactionsSection(client)
                    proSections()
                }
            }
        }
        .detailNavigationTitle(client.fullName, isEmbedded: isEmbedded)
        .sheet(isPresented: $showInvoiceGenerator) {
            InvoiceGeneratorView(clientID: clientID)
        }
        .sheet(isPresented: $showContractGenerator) {
            ContractGeneratorView(clientID: clientID)
        }
        .toolbar { clientToolbar }
    }
    #endif

    #if os(macOS)
    /// One column for the detail pane beside the client list, which is too narrow
    /// for the two-column window layout.
    private func macOSClientPaneLayout(_ client: Client) -> some View {
        Form {
            DetailPaneHeader(title: client.fullName)
            contactSection(client)
            emergencySection(client)
            notesSection(client)
            horsesSection(client)
            transactionsSection(client)
            proSections()
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showInvoiceGenerator) {
            InvoiceGeneratorView(clientID: clientID)
        }
        .sheet(isPresented: $showContractGenerator) {
            ContractGeneratorView(clientID: clientID)
        }
        .toolbar { clientToolbar }
    }

    private func macOSClientLayout(_ client: Client) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: 24) {
                // Left column: contact info + horses
                VStack(spacing: 0) {
                    Form {
                        contactSection(client)
                        emergencySection(client)
                        notesSection(client)
                        horsesSection(client)
                    }
                    .formStyle(.grouped)
                }
                .frame(maxWidth: .infinity)

                // Right column: transactions + invoices/contracts/documents
                VStack(spacing: 0) {
                    Form {
                        transactionsSection(client)
                        proSections()
                    }
                    .formStyle(.grouped)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .detailNavigationTitle(client.fullName, isEmbedded: isEmbedded)
        .sheet(isPresented: $showInvoiceGenerator) {
            InvoiceGeneratorView(clientID: clientID)
        }
        .sheet(isPresented: $showContractGenerator) {
            ContractGeneratorView(clientID: clientID)
        }
        .toolbar { clientToolbar }
    }
    #endif

    private func deleteClient() {
        guard let client else { return }
        BarnHubLogger.info("Deleting client name=\(client.fullName)")
        modelContext.deleteWithLogging(client)
        if let onDelete {
            onDelete()
        } else {
            dismiss()
        }
    }
}
