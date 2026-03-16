import SwiftUI
import SwiftData

struct ClientListView: View {
    @Query(sort: \Client.lastName) private var clients: [Client]
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

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

    var body: some View {
        Group {
            if filteredClients.isEmpty {
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
        .searchable(text: $searchText, prompt: "Search clients")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.navigate(to: ClientRoute.edit(nil))
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Toggle(isOn: $showInactive) {
                    Label("Show Inactive", systemImage: "eye")
                }
                .toggleStyle(.button)
                .tint(showInactive ? .primary : .secondary)
            }
        }
        .navigationDestination(for: ClientRoute.self) { route in
            switch route {
            case .list:
                ClientListView()
            case .detail(let id):
                ClientDetailView(clientID: id)
            case .edit(let id):
                ClientEditView(clientID: id)
            case .manageHorses(let id):
                ClientHorsesView(clientID: id)
            }
        }
    }
}
