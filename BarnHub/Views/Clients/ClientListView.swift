import SwiftUI
import SwiftData

struct ClientListView: View {
    @Query(sort: \Client.lastName) private var clients: [Client]
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(StoreService.self) private var storeService

    @State private var searchText = ""
    @State private var showInactive = false
    @State private var width: CGFloat = 0
    /// Held by ID, not model: the client may be deleted on another device before
    /// the user answers, and reading a deleted model traps.
    @State private var clientPendingRemoval: PersistentIdentifier?
    @State private var toast = ToastState()
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var filteredClients: [Client] {
        clients.filter { client in
            let matchesSearch = searchText.isEmpty
                || client.fullName.localizedCaseInsensitiveContains(searchText)
                || client.email.localizedCaseInsensitiveContains(searchText)
            let matchesActive = showInactive || client.isActive
            return matchesSearch && matchesActive
        }
    }

    private var isPro: Bool { FeatureGate.canAccessClients(storeService.isPro) }

    /// List beside detail when there's room; a pushed detail otherwise.
    private var showsSplit: Bool {
        #if os(iOS)
        guard sizeClass == .regular else { return false }
        #endif
        return width >= ListDetailSplit<EmptyView, EmptyView>.minimumWidth
    }

    var body: some View {
        @Bindable var router = router
        return Group {
            if !isPro {
                ClientsUpgradeView()
            } else if filteredClients.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No Clients",
                    subtitle: "Tap + to add your first client."
                )
            } else if showsSplit {
                ListDetailSplit(width: width) {
                    List(filteredClients, id: \.persistentModelID, selection: $router.selectedClientID) { client in
                        ClientRowView(client: client)
                            .contextMenu { rowActions(client) }
                    }
                } detail: {
                    // Only for an item in the list: a just-inserted item has a temporary
                    // ID until it's saved, and resolving that afterwards traps.
                    if let id = router.selectedClientID,
                       filteredClients.contains(where: { $0.persistentModelID == id }) {
                        ClientDetailView(clientID: id, isEmbedded: true) {
                            router.selectedClientID = nil
                        }
                        .id(id)
                    }
                }
            } else {
                List(filteredClients, id: \.persistentModelID) { client in
                    NavigationLink(value: ClientRoute.detail(client.persistentModelID)) {
                        ClientRowView(client: client)
                    }
                    .contextMenu { rowActions(client) }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: filteredClients.map(\.persistentModelID), initial: true) { _, ids in
            keepSelection(in: ids)
        }
        .onChange(of: showsSplit, initial: true) { _, split in
            router.clientsShowSplit = split
        }
        .overlay {
            ClientRemovalDialog(
                isPresented: Binding(
                    get: { clientPendingRemoval != nil },
                    set: { if !$0 { clientPendingRemoval = nil } }
                ),
                onDeactivate: { removePendingClient(delete: false) },
                onDelete: { removePendingClient(delete: true) }
            )
        }
        .toast(toast)
        .navigationTitle("Clients")
        .inlineNavTitle()
        .searchable(text: $searchText, prompt: "Search clients")
        .prioritizedToolbarItem(.high, placement: .trailingBar, isPresent: isPro) {
            Button {
                router.navigate(to: ClientRoute.edit(nil))
            } label: {
                Label("Add Client", systemImage: "plus")
            }
            .help(Text("Add Client"))
        }
        .toolbar {
            if isPro {
                ToolbarItem(placement: .leadingBar) {
                    Toggle(isOn: $showInactive) {
                        Label("Show Inactive", systemImage: "eye")
                    }
                    .toggleStyle(.button)
                    .help(Text("Show Inactive"))
                }
            }
        }
    }

    /// Right-click (Mac) or long-press actions on a client row.
    @ViewBuilder
    private func rowActions(_ client: Client) -> some View {
        Button {
            router.navigate(to: ClientRoute.edit(client.persistentModelID))
        } label: {
            Label("Edit Client", systemImage: "pencil")
        }
        Button(role: .destructive) {
            clientPendingRemoval = client.persistentModelID
        } label: {
            Label("Delete Client", systemImage: "trash")
        }
    }

    private func removePendingClient(delete: Bool) {
        let id = clientPendingRemoval
        clientPendingRemoval = nil
        guard let client: Client = modelContext.existingModel(for: id) else { return }
        if delete {
            BarnHubLogger.info("Deleting client")
            RecordRemoval.delete(client, in: modelContext)
            toast.show(appLocalized("Client deleted", comment: "Toast after deleting a client"))
        } else {
            BarnHubLogger.info("Deactivating client")
            RecordRemoval.deactivate(client, in: modelContext)
            toast.show(appLocalized("Client deactivated", comment: "Toast after deactivating a client"))
        }
    }

    /// Keeps the split's selection on a client that's still listed, so the detail
    /// pane is never blank while there are clients to show.
    private func keepSelection(in ids: [PersistentIdentifier]) {
        if let id = router.selectedClientID, ids.contains(id) { return }
        router.selectedClientID = ids.first
    }
}

/// Asks whether to deactivate a client (the default, keeps all history) or delete
/// them, instead of a bare "Delete" that would silently take their invoices with them.
struct ClientRemovalDialog: View {
    @Binding var isPresented: Bool
    let onDeactivate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ChoiceDialog(
            isPresented: $isPresented,
            title: "Deactivate or Delete Client?",
            message: "Deactivating hides this client from the list but keeps their invoices, transactions, lessons and documents, so Reports stay the same. Turn on Show Inactive to see them, and reactivate them any time with Edit.\n\nDeleting removes the client with their invoices and documents. Their transactions and lessons are kept without a client.",
            choices: [
                .init(title: "Deactivate Client", isDefault: true, action: onDeactivate),
                .init(title: "Delete Client and Invoices", role: .destructive, action: onDelete),
            ]
        )
    }
}
