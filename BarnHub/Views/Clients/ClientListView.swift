import SwiftUI
import SwiftData

struct ClientListView: View {
    @Query(sort: \Client.lastName) private var clients: [Client]
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(StoreService.self) private var storeService

    @State private var searchText = ""
    @State private var showInactive = false

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

    var body: some View {
        Group {
            if !isPro {
                ClientsUpgradeView()
            } else if filteredClients.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No Clients",
                    subtitle: "Tap + to add your first client."
                )
            } else {
                List(filteredClients, id: \.persistentModelID) { client in
                    NavigationLink(value: ClientRoute.detail(client.persistentModelID)) {
                        ClientRowView(client: client)
                    }
                }
            }
        }
        .navigationTitle("Clients")
        .inlineNavTitle()
        .searchable(text: $searchText, prompt: "Search clients")
        .toolbar {
            if isPro {
                ToolbarItem(placement: .trailingBar) {
                    Button {
                        router.navigate(to: ClientRoute.edit(nil))
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .leadingBar) {
                    Toggle(isOn: $showInactive) {
                        Label("Show Inactive", systemImage: "eye")
                    }
                    .toggleStyle(.button)
                    .tint(showInactive ? .primary : .secondary)
                }
            }
        }
    }
}
