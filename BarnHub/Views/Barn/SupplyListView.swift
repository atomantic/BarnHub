import SwiftUI
import SwiftData

struct SupplyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(sort: \SupplyItem.name) private var supplyItems: [SupplyItem]

    @State private var searchText = ""
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: SupplyItem?
    @State private var toast = ToastState()

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
            } else {
                List {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: BarnRoute.supplyEdit(item.persistentModelID)) {
                            supplyRow(item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                itemToDelete = item
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
        }
        .overlay {
            ConfirmationDialog(
                isPresented: $showDeleteConfirmation,
                title: "Delete Supply",
                message: "Are you sure you want to delete \(itemToDelete?.name ?? "this item")?",
                confirmTitle: "Delete",
                confirmRole: .destructive
            ) {
                guard let item = itemToDelete else { return }
                modelContext.deleteWithLogging(item)
                toast.show(appLocalized("Supply deleted"))
                itemToDelete = nil
            }
        }
        .toast(toast)
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
    }
}
