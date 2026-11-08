import SwiftUI
import SwiftData

struct HorseListView: View {
    @Query(sort: \Horse.name) private var horses: [Horse]
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @State private var searchText = ""
    @State private var showInactive = false
    @State private var selectedHorseID: PersistentIdentifier?
    @State private var width: CGFloat = 0
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var filteredHorses: [Horse] {
        horses.filter { horse in
            let matchesSearch = searchText.isEmpty
                || horse.name.localizedCaseInsensitiveContains(searchText)
                || horse.breed.localizedCaseInsensitiveContains(searchText)
            let matchesActive = showInactive || horse.isActive
            return matchesSearch && matchesActive
        }
    }

    /// List beside detail when there's room; a pushed detail otherwise.
    private var showsSplit: Bool {
        #if os(iOS)
        guard sizeClass == .regular else { return false }
        #endif
        return width >= ListDetailSplit<EmptyView, EmptyView>.minimumWidth
    }

    var body: some View {
        Group {
            if filteredHorses.isEmpty {
                EmptyStateView(
                    icon: "horse",
                    title: "No Horses",
                    subtitle: "Tap + to add your first horse."
                )
            } else if showsSplit {
                ListDetailSplit(width: width) {
                    List(filteredHorses, id: \.persistentModelID, selection: $selectedHorseID) { horse in
                        HorseRowView(horse: horse)
                    }
                } detail: {
                    if let selectedHorseID {
                        HorseDetailView(horseID: selectedHorseID, isEmbedded: true) {
                            self.selectedHorseID = nil
                        }
                        .id(selectedHorseID)
                    }
                }
            } else {
                List(filteredHorses, id: \.persistentModelID) { horse in
                    NavigationLink(value: HorseRoute.detail(horse.persistentModelID)) {
                        HorseRowView(horse: horse)
                    }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: filteredHorses.map(\.persistentModelID), initial: true) { _, ids in
            keepSelection(in: ids)
        }
        .navigationTitle("Horses")
        .inlineNavTitle()
        .searchable(text: $searchText, prompt: "Search horses")
        .prioritizedToolbarItem(.high, placement: .trailingBar) {
            Button {
                router.navigate(to: HorseRoute.edit(nil))
            } label: {
                Label("Add Horse", systemImage: "plus")
            }
        }
        .toolbar {
            ToolbarItem(placement: .leadingBar) {
                Toggle(isOn: $showInactive) {
                    Label("Show Inactive", systemImage: "eye")
                }
                .toggleStyle(.button)
                .tint(showInactive ? .primary : .secondary)
            }
        }
    }

    /// Keeps the split's selection on a horse that's still listed, so the detail
    /// pane is never blank while there are horses to show.
    private func keepSelection(in ids: [PersistentIdentifier]) {
        if let selectedHorseID, ids.contains(selectedHorseID) { return }
        selectedHorseID = ids.first
    }
}
