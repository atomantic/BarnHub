import SwiftUI
import SwiftData

struct FeedPlanEntryEditView: View {
    let horseID: PersistentIdentifier
    let entryID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FeedProduct.name) private var products: [FeedProduct]

    @State private var selectedProduct: FeedProduct?
    @State private var amount: Double = 1.0
    @State private var unit: FeedUnit = .scoops
    @State private var feedTime: FeedTime = .morning
    @State private var assignedPerson = ""
    @State private var notes = ""
    @State private var toast = ToastState()

    private var isNew: Bool { entryID == nil }
    private var existingEntry: FeedPlanEntry? { modelContext.existingModel(for: entryID) }
    private var horse: Horse? { modelContext.model(for: horseID) as? Horse }

    var body: some View {
        Form {
            Section("Feed Product") {
                if products.isEmpty {
                    Text("No feed products yet. Add one from the barn menu first.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Product", selection: $selectedProduct) {
                        Text("Select a product").tag(nil as FeedProduct?)
                        ForEach(products, id: \.persistentModelID) { product in
                            HStack {
                                Text(product.name)
                                if !product.brand.isEmpty {
                                    Text("(\(product.brand))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(product as FeedProduct?)
                        }
                    }
                }
            }

            Section("Amount") {
                HStack {
                    Text("Quantity")
                    Spacer()
                    TextField("1", value: $amount, format: .number)
                        .decimalKeyboard()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Picker("Unit", selection: $unit) {
                    ForEach(FeedUnit.allCases) { u in
                        Text(u.displayName).tag(u)
                    }
                }
            }

            Section("Schedule") {
                Picker("Time of Day", selection: $feedTime) {
                    ForEach(FeedTime.allCases) { t in
                        Label(t.displayName, systemImage: t.icon).tag(t)
                    }
                }
                TextField("Assigned Person", text: $assignedPerson)
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 60)
            }

            Section {
                Button(isNew ? "Add to Feed Plan" : "Save Changes") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .disabled(selectedProduct == nil)
            }
        }
        .navigationTitle(isNew ? "Add Feed Item" : "Edit Feed Item")
        .inlineNavTitle()
        .toast(toast)
        .task { loadExisting() }
    }

    private func loadExisting() {
        guard let entry = existingEntry else { return }
        selectedProduct = entry.product
        amount = entry.amount
        unit = entry.unit
        feedTime = entry.feedTime
        assignedPerson = entry.assignedPerson
        notes = entry.notes
    }

    private func save() {
        guard let product = selectedProduct else { return }

        if let entry = existingEntry {
            entry.product = product
            entry.amount = amount
            entry.unit = unit
            entry.feedTime = feedTime
            entry.assignedPerson = assignedPerson
            entry.notes = notes
            BarnHubLogger.info("Updating feed entry horse=\(horse?.name ?? "?") product=\(product.name)")
        } else {
            let entry = FeedPlanEntry(
                amount: amount,
                unit: unit,
                feedTime: feedTime,
                assignedPerson: assignedPerson,
                notes: notes
            )
            entry.horse = horse
            entry.product = product
            modelContext.insert(entry)
            BarnHubLogger.info("Adding feed entry horse=\(horse?.name ?? "?") product=\(product.name)")
        }

        modelContext.saveWithLogging()
        toast.showAndDismiss(
            isNew ? appLocalized("Feed item added") : appLocalized("Feed item updated"),
            dismiss: dismiss
        )
    }
}
