import SwiftUI
import SwiftData

struct HorseListView: View {
    @Query(sort: \Horse.name) private var horses: [Horse]
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(NotificationService.self) private var notificationService

    @State private var searchText = ""
    @State private var showInactive = false
    @State private var width: CGFloat = 0
    /// Held by ID, not model: the horse may be deleted on another device before
    /// the user answers, and reading a deleted model traps.
    @State private var horsePendingRemoval: PersistentIdentifier?
    @State private var toast = ToastState()
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
            HorseRemovalDialog(
                isPresented: Binding(
                    get: { horsePendingRemoval != nil },
                    set: { if !$0 { horsePendingRemoval = nil } }
                ),
                onMarkInactive: { removePendingHorse(delete: false) },
                onDelete: { removePendingHorse(delete: true) }
            )
        }
        .toast(toast)
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
            horsePendingRemoval = horse.persistentModelID
        } label: {
            Label("Delete Horse", systemImage: "trash")
        }
    }

    private func removePendingHorse(delete: Bool) {
        let id = horsePendingRemoval
        horsePendingRemoval = nil
        guard let horse: Horse = modelContext.existingModel(for: id) else { return }
        if delete {
            BarnHubLogger.info("Deleting horse name=\(horse.name)")
            notificationService.cancelNotifications(for: horse)
            RecordRemoval.delete(horse, in: modelContext)
            toast.show(appLocalized("Horse deleted", comment: "Toast after deleting a horse"))
        } else {
            BarnHubLogger.info("Marking horse inactive name=\(horse.name)")
            RecordRemoval.markInactive(horse, in: modelContext)
            toast.show(appLocalized("Horse marked inactive", comment: "Toast after marking a horse inactive"))
        }
    }

    /// Keeps the split's selection on a horse that's still listed, so the detail
    /// pane is never blank while there are horses to show.
    private func keepSelection(in ids: [PersistentIdentifier]) {
        if let id = router.selectedHorseID, ids.contains(id) { return }
        router.selectedHorseID = ids.first
    }
}

/// Asks whether to mark a horse inactive (the default, keeps every record) or
/// delete it, and says exactly what a delete removes.
struct HorseRemovalDialog: View {
    @Binding var isPresented: Bool
    let onMarkInactive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ChoiceDialog(
            isPresented: $isPresented,
            title: "Mark Inactive or Delete Horse?",
            message: "Marking inactive hides this horse from the list but keeps all of its records. Turn on Show Inactive to see it, and reactivate it any time with Edit.\n\nDeleting removes the horse with its vet, farrier and dentist records, reminders, weights, barn notes, documents and feed plan. Its lessons are kept without a horse.",
            choices: [
                .init(title: "Mark Inactive", isDefault: true, action: onMarkInactive),
                .init(title: "Delete Horse and Records", role: .destructive, action: onDelete),
            ]
        )
    }
}
