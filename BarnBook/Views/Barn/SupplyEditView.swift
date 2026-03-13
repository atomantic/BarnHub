import SwiftUI
import SwiftData

struct SupplyEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let supplyItemID: PersistentIdentifier?

    @State private var name = ""
    @State private var categoryRaw = ""
    @State private var quantity: Double = 0
    @State private var unit = ""
    @State private var reorderThreshold: Double = 0
    @State private var lastOrderedDate: Date?
    @State private var showLastOrderedDate = false

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    private var isNew: Bool { supplyItemID == nil }
    private var existingItem: SupplyItem? {
        guard let id = supplyItemID else { return nil }
        return modelContext.model(for: id) as? SupplyItem
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                TextField("Category", text: $categoryRaw)
                HStack {
                    Text("Quantity")
                    Spacer()
                    TextField("0", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                TextField("Unit (e.g., lbs, bags)", text: $unit)
                HStack {
                    Text("Reorder Threshold")
                    Spacer()
                    TextField("0", value: $reorderThreshold, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Last Ordered") {
                Toggle("Track Last Order Date", isOn: $showLastOrderedDate)
                if showLastOrderedDate {
                    DatePicker(
                        "Last Ordered",
                        selection: Binding(
                            get: { lastOrderedDate ?? .now },
                            set: { lastOrderedDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
            }
        }
        .navigationTitle(isNew ? "New Supply" : "Edit Supply")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: loadExisting)
        .toast(isPresented: $showToast, message: toastMessage, isError: toastIsError)
    }

    private func loadExisting() {
        guard let item = existingItem else { return }
        name = item.name
        categoryRaw = item.categoryRaw
        quantity = item.quantity
        unit = item.unit
        reorderThreshold = item.reorderThreshold
        lastOrderedDate = item.lastOrderedDate
        showLastOrderedDate = item.lastOrderedDate != nil
    }

    private func save() {
        let item: SupplyItem
        if let existing = existingItem {
            item = existing
        } else {
            item = SupplyItem()
            modelContext.insert(item)
        }

        item.name = name.trimmingCharacters(in: .whitespaces)
        item.categoryRaw = categoryRaw.trimmingCharacters(in: .whitespaces)
        item.quantity = quantity
        item.unit = unit.trimmingCharacters(in: .whitespaces)
        item.reorderThreshold = reorderThreshold
        item.lastOrderedDate = showLastOrderedDate ? lastOrderedDate : nil

        modelContext.saveWithLogging()

        toastMessage = isNew ? "Supply added" : "Supply updated"
        toastIsError = false
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}
