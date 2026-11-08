import SwiftUI
import SwiftData

struct HorseListView: View {
    @Query(sort: \Horse.name) private var horses: [Horse]
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @State private var searchText = ""
    @State private var showInactive = false
    @State private var width: CGFloat = 0
    @State private var horsePendingDelete: Horse?
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
        @Bindable var router = router
        return Group {
            if filteredHorses.isEmpty {
                EmptyStateView(
                    icon: "horse",
                    title: "No Horses",
                    subtitle: "Tap + to add your first horse."
                )
            } else if showsSplit {
                ListDetailSplit(width: width) {
                    List(filteredHorses, id: \.persistentModelID, selection: $router.selectedHorseID) { horse in
                        HorseRowView(horse: horse)
                            .contextMenu { rowActions(horse) }
                    }
                } detail: {
                    // Only for an item in the list: a just-inserted item has a temporary
                    // ID until it's saved, and resolving that afterwards traps.
                    if let id = router.selectedHorseID,
                       filteredHorses.contains(where: { $0.persistentModelID == id }) {
                        HorseDetailView(horseID: id, isEmbedded: true) {
                            router.selectedHorseID = nil
                        }
                        .id(id)
                    }
                }
            } else {
                List(filteredHorses, id: \.persistentModelID) { horse in
                    NavigationLink(value: HorseRoute.detail(horse.persistentModelID)) {
                        HorseRowView(horse: horse)
                    }
                    .contextMenu { rowActions(horse) }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: filteredHorses.map(\.persistentModelID), initial: true) { _, ids in
            keepSelection(in: ids)
        }
        .onChange(of: showsSplit, initial: true) { _, split in
            router.horsesShowSplit = split
        }
        .overlay {
            ConfirmationDialog(
                isPresented: Binding(
                    get: { horsePendingDelete != nil },
                    set: { if !$0 { horsePendingDelete = nil } }
                ),
                title: "Delete Horse",
                message: "Are you sure you want to delete this horse? All associated vet records, farrier visits, and dentist visits will also be removed.",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: deletePendingHorse
            )
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
            .help(Text("Add Horse"))
        }
        .toolbar {
            ToolbarItem(placement: .leadingBar) {
                Toggle(isOn: $showInactive) {
                    Label("Show Inactive", systemImage: "eye")
                }
                .toggleStyle(.button)
                .help(Text("Show Inactive"))
            }
        }
    }

    /// Right-click (Mac) or long-press actions on a horse row.
    @ViewBuilder
    private func rowActions(_ horse: Horse) -> some View {
        Button {
            router.navigate(to: HorseRoute.edit(horse.persistentModelID))
        } label: {
            Label("Edit Horse", systemImage: "pencil")
        }
        Button(role: .destructive) {
            horsePendingDelete = horse
        } label: {
            Label("Delete Horse", systemImage: "trash")
        }
    }

    private func deletePendingHorse() {
        guard let horse = horsePendingDelete else { return }
        horsePendingDelete = nil
        BarnHubLogger.info("Deleting horse name=\(horse.name)")
        modelContext.deleteWithLogging(horse)
    }

    /// Keeps the split's selection on a horse that's still listed, so the detail
    /// pane is never blank while there are horses to show.
    private func keepSelection(in ids: [PersistentIdentifier]) {
        if let id = router.selectedHorseID, ids.contains(id) { return }
        router.selectedHorseID = ids.first
    }
}
