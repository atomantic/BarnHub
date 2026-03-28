import SwiftUI
import SwiftData

struct ClientPickerSection: View {
    @Binding var selectedClientID: PersistentIdentifier?
    var placeholder: String = "None"

    @Query(sort: \Client.lastName) private var clients: [Client]

    var body: some View {
        Section("Client") {
            Picker("Assign Client", selection: $selectedClientID) {
                Text(placeholder).tag(nil as PersistentIdentifier?)
                ForEach(clients) { client in
                    Text(client.fullName).tag(client.persistentModelID as PersistentIdentifier?)
                }
            }
        }
    }
}
