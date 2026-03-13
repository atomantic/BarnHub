import SwiftUI
import SwiftData

struct ClientDetailView: View {
    let clientID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    private var client: Client? {
        modelContext.model(for: clientID) as? Client
    }

    var body: some View {
        Group {
            if let client {
                clientContent(client)
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Client Not Found",
                    subtitle: "This client may have been deleted."
                )
            }
        }
        .overlay {
            ConfirmationDialog(
                isPresented: $showDeleteConfirmation,
                title: "Delete Client",
                message: "Are you sure you want to delete this client? All associated transactions will also be removed.",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: deleteClient
            )
        }
        .toast(isPresented: $showToast, message: toastMessage, isError: toastIsError)
    }

    @ViewBuilder
    private func clientContent(_ client: Client) -> some View {
        List {
            Section("Contact Info") {
                if !client.email.isEmpty {
                    LabeledContent("Email", value: client.email)
                }
                if !client.phone.isEmpty {
                    LabeledContent("Phone", value: client.phone)
                }
                LabeledContent("Status", value: client.isActive ? "Active" : "Inactive")
            }

            Section("Emergency Contact") {
                if client.emergencyContact.isEmpty && client.emergencyPhone.isEmpty {
                    Text("No emergency contact on file")
                        .foregroundStyle(.secondary)
                } else {
                    if !client.emergencyContact.isEmpty {
                        LabeledContent("Name", value: client.emergencyContact)
                    }
                    if !client.emergencyPhone.isEmpty {
                        LabeledContent("Phone", value: client.emergencyPhone)
                    }
                }
            }

            if !client.notes.isEmpty {
                Section("Notes") {
                    Text(client.notes)
                }
            }

            Section {
                let horses = (client.horses ?? []).sorted { $0.name < $1.name }
                if horses.isEmpty {
                    Text("No assigned horses")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(horses, id: \.persistentModelID) { horse in
                        NavigationLink(value: HorseRoute.detail(horse.persistentModelID)) {
                            HorseRowView(horse: horse)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Horses")
                    Spacer()
                    Button {
                        router.navigate(to: ClientRoute.manageHorses(clientID), tab: .clients)
                    } label: {
                        Image(systemName: "pencil.circle")
                    }
                }
            }

            Section {
                let transactions = (client.transactions ?? [])
                    .sorted { $0.date > $1.date }
                    .prefix(5)
                if transactions.isEmpty {
                    Text("No transactions")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(transactions, id: \.persistentModelID) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.category.displayName)
                                    .font(.subheadline)
                                Text(transaction.date.shortFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(transaction.amount.asCurrency)
                                    .font(.subheadline)
                                    .foregroundStyle(transaction.type == .income ? .green : .primary)
                                if transaction.isPaid {
                                    Text("Paid")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Unpaid")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    if (client.transactions ?? []).count > 5 {
                        NavigationLink(value: ClientRoute.detail(clientID)) {
                            Text("View All Transactions")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            } header: {
                Text("Recent Transactions")
            }
        }
        .navigationTitle(client.fullName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        router.navigate(to: ClientRoute.edit(clientID), tab: .clients)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func deleteClient() {
        guard let client else { return }
        BarnBookLogger.info("Deleting client name=\(client.fullName)")
        modelContext.deleteWithLogging(client)
        dismiss()
    }
}
