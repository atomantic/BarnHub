import SwiftUI
import SwiftData

struct ClientHorsesView: View {
    let clientID: PersistentIdentifier
    @Query(sort: \Horse.name) private var allHorses: [Horse]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var toast = ToastState()

    private var client: Client? {
        modelContext.existingModel(for: clientID)
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
        .inlineNavTitle()
        .toast(toast)
    }

    private func toggleHorse(_ horse: Horse, for client: Client, currentlyAssigned: Bool) {
        if currentlyAssigned {
            client.horses?.removeAll { $0.persistentModelID == horse.persistentModelID }
            toast.show(appLocalized("\(horse.name) removed", comment: "Horse unassigned notification"))
            BarnHubLogger.info("Unassigned horse from client horses=\(client.horses?.count ?? 0)")
        } else {
            if client.horses == nil {
                client.horses = []
            }
            client.horses?.append(horse)
            toast.show(appLocalized("\(horse.name) assigned", comment: "Horse assigned notification"))
            BarnHubLogger.info("Assigned horse to client horses=\(client.horses?.count ?? 0)")
        }
        modelContext.saveWithLogging()
    }
}
