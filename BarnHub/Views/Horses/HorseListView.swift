import SwiftUI
import SwiftData

struct HorseListView: View {
    @Query(sort: \Horse.name) private var horses: [Horse]
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @State private var searchText = ""
    @State private var showInactive = false

    private var filteredHorses: [Horse] {
        horses.filter { horse in
            let matchesSearch = searchText.isEmpty
                || horse.name.localizedCaseInsensitiveContains(searchText)
                || horse.breed.localizedCaseInsensitiveContains(searchText)
            let matchesActive = showInactive || horse.isActive
            return matchesSearch && matchesActive
        }
    }

    var body: some View {
        Group {
            if filteredHorses.isEmpty {
                EmptyStateView(
                    icon: "horse",
                    title: "No Horses",
                    subtitle: "Tap + to add your first horse."
                )
            } else {
                List(filteredHorses, id: \.persistentModelID) { horse in
                    NavigationLink(value: HorseRoute.detail(horse.persistentModelID)) {
                        HorseRowView(horse: horse)
                    }
                }
            }
        }
        .navigationTitle("Horses")
        .inlineNavTitle()
        .searchable(text: $searchText, prompt: "Search horses")
        .toolbar {
            ToolbarItem(placement: .trailingBar) {
                Button {
                    router.navigate(to: HorseRoute.edit(nil))
                } label: {
                    Label("Add Horse", systemImage: "plus")
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
