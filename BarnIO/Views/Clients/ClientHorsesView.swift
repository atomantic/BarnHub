import SwiftUI
import SwiftData

struct ClientHorsesView: View {
    let clientID: PersistentIdentifier
    @Query(sort: \Horse.name) private var allHorses: [Horse]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showToast = false
    @State private var toastMessage = ""

    private var client: Client? {
        modelContext.model(for: clientID) as? Client
    }

    var body: some View {
        Group {
            if let client {
                List(allHorses, id: \.persistentModelID) { horse in
                    let isAssigned = (client.horses ?? []).contains(where: {
                        $0.persistentModelID == horse.persistentModelID
                    })
                    Button {
                        toggleHorse(horse, for: client, currentlyAssigned: isAssigned)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(horse.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if !horse.breed.isEmpty {
                                    Text(horse.breed)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if isAssigned {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .imageScale(.large)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                                    .imageScale(.large)
                            }
                        }
                    }
                }
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Client Not Found",
                    subtitle: "This client may have been deleted."
                )
            }
        }
        .navigationTitle("Manage Horses")
        .toast(isPresented: $showToast, message: toastMessage)
    }

    private func toggleHorse(_ horse: Horse, for client: Client, currentlyAssigned: Bool) {
        if currentlyAssigned {
            client.horses?.removeAll { $0.persistentModelID == horse.persistentModelID }
            toastMessage = "\(horse.name) removed"
            BarnIOLogger.info("Unassigned horse=\(horse.name) from client=\(client.fullName)")
        } else {
            if client.horses == nil {
                client.horses = []
            }
            client.horses?.append(horse)
            toastMessage = "\(horse.name) assigned"
            BarnIOLogger.info("Assigned horse=\(horse.name) to client=\(client.fullName)")
        }
        modelContext.saveWithLogging()
        showToast = true
    }
}
