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
        modelContext.existingModel(for: clientID)
    }

    /// The client's five newest transactions, fetched with a limit instead of
    /// loading and sorting all of them (#32).
    private var recentTransactionsDescriptor: FetchDescriptor<Transaction> {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: Transaction.forClient(clientID),
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        return descriptor
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
            ClientRemovalDialog(
                isPresented: $showDeleteConfirmation,
                onDeactivate: deactivateClient,
                onDelete: deleteClient
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
        QueryContent(recentTransactionsDescriptor) { recentTransactions in
            transactionsSection(
                recentTransactions: recentTransactions,
                // Re-counted whenever the query refreshes after a save or sync.
                allTransactionsCount: (try? modelContext.fetchCount(FetchDescriptor(predicate: Transaction.forClient(clientID)))) ?? 0
            )
        }
    }

    private func transactionsSection(recentTransactions: [Transaction], allTransactionsCount: Int) -> some View {
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
                            Text(transaction.signedAmount.asCurrency)
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
                .accessibilityIdentifier("client_documents_row")  // ScreenWalkTests
            }
        }
    }

    private func paneHeader(_ client: Client) -> some View {
        DetailPaneHeader(
            title: client.fullName,
            onEdit: { router.navigate(to: ClientRoute.edit(clientID)) },
            onDelete: { showDeleteConfirmation = true }
        )
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
            .help(Text("Edit"))
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .help(Text("Delete"))
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
            // The embedded pane beside the list is too narrow for two columns.
            if sizeClass == .regular && !isEmbedded {
                // Same split as macOS: contact + horses left, money + documents right.
                WideColumns {
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
                    if isEmbedded { paneHeader(client) }
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
        .generatorSheets(clientID: clientID, showInvoice: $showInvoiceGenerator, showContract: $showContractGenerator)
        .toolbar { if !isEmbedded { clientToolbar } }
    }
    #endif

    #if os(macOS)
    /// One column for the detail pane beside the client list, which is too narrow
    /// for the two-column window layout.
    private func macOSClientPaneLayout(_ client: Client) -> some View {
        Form {
            paneHeader(client)
            contactSection(client)
            emergencySection(client)
            notesSection(client)
            horsesSection(client)
            transactionsSection(client)
            proSections()
        }
        .formStyle(.grouped)
        .generatorSheets(clientID: clientID, showInvoice: $showInvoiceGenerator, showContract: $showContractGenerator)
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
        .generatorSheets(clientID: clientID, showInvoice: $showInvoiceGenerator, showContract: $showContractGenerator)
        .toolbar { clientToolbar }
    }
    #endif

    private func deactivateClient() {
        guard let client else { return }
        BarnHubLogger.info("Deactivating client")
        RecordRemoval.deactivate(client, in: modelContext)
        toast.show(appLocalized("Client deactivated", comment: "Toast after deactivating a client"))
    }

    private func deleteClient() {
        guard let client else { return }
        BarnHubLogger.info("Deleting client")
        RecordRemoval.delete(client, in: modelContext)
        if let onDelete {
            onDelete()
        } else {
            dismiss()
        }
    }
}

private extension View {
    /// The invoice and contract generators, attached to whichever layout is showing.
    func generatorSheets(clientID: PersistentIdentifier, showInvoice: Binding<Bool>, showContract: Binding<Bool>) -> some View {
        self
            .sheet(isPresented: showInvoice) {
                InvoiceGeneratorView(clientID: clientID)
            }
            .sheet(isPresented: showContract) {
                ContractGeneratorView(clientID: clientID)
            }
    }
}
