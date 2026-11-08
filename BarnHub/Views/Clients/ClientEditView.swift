import SwiftUI
import SwiftData

struct ClientEditView: View {
    let clientID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var emergencyContact = ""
    @State private var emergencyPhone = ""
    @State private var notes = ""
    @State private var isActive = true

    @State private var toast = ToastState()

    private var isNew: Bool { clientID == nil }
    private var existingClient: Client? { modelContext.existingModel(for: clientID) }
    /// Editing a record that was deleted meanwhile (here or on another device).
    private var wasDeletedElsewhere: Bool { modelContext.isDeletedRecord(clientID, as: Client.self) }
    private var navigationTitleKey: LocalizedStringKey { isNew ? "New Client" : "Edit Client" }

    var body: some View {
        Form {
            Section("Name") {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
            }

            Section("Contact") {
                TextField("Email", text: $email)
                    .emailKeyboard()
                    .textContentType(.emailAddress)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                TextField("Phone", text: $phone)
                    .phoneKeyboard()
                    .textContentType(.telephoneNumber)
            }

            Section("Emergency Contact") {
                TextField("Contact Name", text: $emergencyContact)
                TextField("Contact Phone", text: $emergencyPhone)
                    .phoneKeyboard()
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
            }

            Section {
                Toggle("Active", isOn: $isActive)
            }

        }
        .navigationTitle(navigationTitleKey)
        .toolbar {
            // In the bar rather than at the bottom of the form, so it's always
            // reachable and sits next to Cancel when the form opens as a sheet.
            ToolbarItem(placement: .pinnedConfirmation) {
                Button(isNew ? "Add" : "Save") { save() }
                    .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty
                    && lastName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .inlineNavTitle()
        #if os(macOS)
        .formStyle(.grouped)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        #endif
        .deletedRecordNotice(wasDeletedElsewhere)
        .toast(toast)
        .task { loadExisting() }
    }

    private func loadExisting() {
        guard let client = existingClient else { return }
        firstName = client.firstName
        lastName = client.lastName
        email = client.email
        phone = client.phone
        emergencyContact = client.emergencyContact
        emergencyPhone = client.emergencyPhone
        notes = client.notes
        isActive = client.isActive
    }

    private func save() {
        // Never insert a replacement for a record deleted while the form was open.
        guard !wasDeletedElsewhere else {
            toast.showAndDismiss(appLocalized("This item was deleted", comment: "Toast when saving a record that was deleted elsewhere"), isError: true, dismiss: dismiss)
            return
        }
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        guard !trimmedFirst.isEmpty || !trimmedLast.isEmpty else { return }
        var newClient: Client?

        if let client = existingClient {
            client.firstName = trimmedFirst
            client.lastName = trimmedLast
            client.email = email
            client.phone = phone
            client.emergencyContact = emergencyContact
            client.emergencyPhone = emergencyPhone
            client.notes = notes
            client.isActive = isActive
            BarnHubLogger.info("Updating client")
        } else {
            let client = Client(
                firstName: trimmedFirst,
                lastName: trimmedLast,
                email: email,
                phone: phone,
                emergencyContact: emergencyContact,
                emergencyPhone: emergencyPhone,
                notes: notes,
                isActive: isActive
            )
            modelContext.insert(client)
            BarnHubLogger.info("Creating client")
            newClient = client
        }

        modelContext.saveWithLogging()
        // Show the new client beside the list; read the ID after saving (see HorseEditView).
        if let newClient, router.clientsShowSplit {
            router.selectedClientID = newClient.persistentModelID
        }
        toast.showAndDismiss(isNew ? appLocalized("Client added") : appLocalized("Client updated"), dismiss: dismiss)
    }
}
