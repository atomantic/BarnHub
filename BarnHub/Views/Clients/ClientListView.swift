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
    @State private var clientPendingDelete: Client?
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
                    if let id = router.selectedClientID {
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
            ConfirmationDialog(
                isPresented: Binding(
                    get: { clientPendingDelete != nil },
                    set: { if !$0 { clientPendingDelete = nil } }
                ),
                title: "Delete Client",
                message: "Are you sure you want to delete this client? All associated transactions will also be removed.",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: deletePendingClient
            )
        }
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
                    .tint(showInactive ? .primary : .secondary)
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
            clientPendingDelete = client
        } label: {
            Label("Delete Client", systemImage: "trash")
        }
    }

    private func deletePendingClient() {
        guard let client = clientPendingDelete else { return }
        clientPendingDelete = nil
        BarnHubLogger.info("Deleting client name=\(client.fullName)")
        modelContext.deleteWithLogging(client)
    }

    /// Keeps the split's selection on a client that's still listed, so the detail
    /// pane is never blank while there are clients to show.
    private func keepSelection(in ids: [PersistentIdentifier]) {
        if let id = router.selectedClientID, ids.contains(id) { return }
        router.selectedClientID = ids.first
    }
}
