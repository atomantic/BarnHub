import SwiftUI
import SwiftData

struct SupplyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(sort: \SupplyItem.name) private var supplyItems: [SupplyItem]

    @State private var searchText = ""
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: PendingDeletion?
    @State private var toast = ToastState()
    @State private var sortOrder = [KeyPathComparator(\SupplyItem.name)]
    @State private var selection: PersistentIdentifier?
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// A sortable table on the Mac and at regular width; a list of rows on iPhone.
    private var usesTable: Bool {
        #if os(iOS)
        sizeClass == .regular
        #else
        true
        #endif
    }

    private var filteredItems: [SupplyItem] {
        guard !searchText.isEmpty else { return supplyItems }
        return supplyItems.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if filteredItems.isEmpty {
                EmptyStateView(
                    icon: "shippingbox",
                    title: "No Supplies",
                    subtitle: "Tap + to add your first supply item."
                )
            } else if usesTable {
                supplyTable
            } else {
                List {
                    ForEach(filteredItems) { item in
                        Button {
                            router.navigate(to: BarnRoute.supplyEdit(item.persistentModelID))
                        } label: {
                            supplyRow(item)
                        }
                        .foregroundStyle(.primary)  // not .tint(.primary): a hierarchical tint can loop endlessly on Mac Catalyst
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                itemToDelete = PendingDeletion(id: item.persistentModelID, name: item.name)
                                showDeleteConfirmation = true
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search supplies")
        .navigationTitle("Supplies")
        .inlineNavTitle()
        .prioritizedToolbarItem(.high, placement: .primaryAction) {
            Button {
                router.navigate(to: BarnRoute.supplyEdit(nil))
            } label: {
                Label("New Supply", systemImage: "plus")
            }
            .help(Text("New Supply"))
        }
        .overlay {
            ConfirmationDialog(
                isPresented: $showDeleteConfirmation,
                title: "Delete Supply",
                message: "Are you sure you want to delete \(itemToDelete?.name ?? "this item")?",
                confirmTitle: "Delete",
                confirmRole: .destructive
            ) {
                guard let pending = itemToDelete,
                      let item: SupplyItem = modelContext.existingModel(for: pending.id) else {
                    itemToDelete = nil
                    return
                }
                modelContext.deleteWithLogging(item)
                toast.show(appLocalized("Supply deleted"))
                itemToDelete = nil
            }
        }
        .toast(toast)
    }

    private var supplyTable: some View {
        Table(filteredItems.sorted(using: sortOrder), selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name)
            TableColumn("Quantity", value: \.quantity) { item in
                Text(item.quantity, format: .number.precision(.fractionLength(0...1)))
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 80)
            TableColumn("Unit", value: \.unit)
                .width(min: 60, ideal: 90)
            TableColumn("Reorder Threshold", value: \.reorderThreshold) { item in
                Text(item.reorderThreshold, format: .number.precision(.fractionLength(0...1)))
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 120)
            TableColumn("Last Ordered") { item in
                if let date = item.lastOrderedDate {
                    Text(date, format: .dateTime.year().month(.abbreviated).day())
                } else {
                    Text(verbatim: "—")
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 90, ideal: 110)
            TableColumn("Status") { item in
                stockBadge(item)
            }
            .width(min: 50, ideal: 70)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            if let id = ids.first, let item = filteredItems.first(where: { $0.persistentModelID == id }) {
                Button {
                    router.navigate(to: BarnRoute.supplyEdit(id))
                } label: {
                    Label("Edit Supply", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    itemToDelete = PendingDeletion(id: item.persistentModelID, name: item.name)
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Supply", systemImage: "trash")
                }
            }
        } primaryAction: { ids in
            // Double-click (or Return) opens the item.
            if let id = ids.first {
                router.navigate(to: BarnRoute.supplyEdit(id))
            }
        }
    }

    @ViewBuilder
    private func stockBadge(_ item: SupplyItem) -> some View {
        if item.isLowStock {
            HStack(spacing: 4) {
                Image(systemName: item.quantity <= 0 ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                Text(item.quantity <= 0 ? "Out" : "Low")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(item.quantity <= 0 ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
            )
            .foregroundStyle(item.quantity <= 0 ? .red : .orange)
        }
    }

    private func supplyRow(_ item: SupplyItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                Text("\(item.quantity, specifier: "%.0f") \(item.unit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            stockBadge(item)
        }
    }
}
