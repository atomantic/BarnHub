import SwiftUI
import SwiftData

struct FeedProductListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(sort: \FeedProduct.name) private var products: [FeedProduct]

    @State private var showDeleteConfirmation = false
    @State private var productToDelete: FeedProduct?
    @State private var toast = ToastState()

    var body: some View {
        Group {
            if products.isEmpty {
                EmptyStateView(
                    icon: "leaf",
                    title: "No Feed Products",
                    subtitle: "Tap + to add grain, hay, supplements, and other feed products."
                )
            } else {
                List {
                    ForEach(products, id: \.persistentModelID) { product in
                        Button {
                            router.navigate(to: BarnRoute.feedProductEdit(product.persistentModelID))
                        } label: {
                            productRow(product)
                        }
                        .foregroundStyle(.primary)  // not .tint(.primary): a hierarchical tint can loop endlessly on Mac Catalyst
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                productToDelete = product
                                showDeleteConfirmation = true
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Feed Products")
        .inlineNavTitle()
        .prioritizedToolbarItem(.high, placement: .primaryAction) {
            Button {
                router.navigate(to: BarnRoute.feedProductEdit(nil))
            } label: {
                Label("New Feed Product", systemImage: "plus")
            }
        }
        .overlay {
            ConfirmationDialog(
                isPresented: $showDeleteConfirmation,
                title: "Delete Product",
                message: "Are you sure you want to delete \"\(productToDelete?.name ?? "this product")\"? Feed plan entries using this product will lose their product reference.",
                confirmTitle: "Delete",
                confirmRole: .destructive
            ) {
                guard let product = productToDelete else { return }
                modelContext.deleteWithLogging(product)
                toast.show(appLocalized("Product deleted"))
                productToDelete = nil
            }
        }
        .toast(toast)
    }

    private func productRow(_ product: FeedProduct) -> some View {
        HStack(spacing: 12) {
            if let photoData = product.photoData, let image = Image(photoData: photoData) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.barnGreen)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(Color.barnGreen.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.headline)
                if !product.brand.isEmpty {
                    Text(product.brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(product.defaultUnit.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
