import SwiftUI
import SwiftData

struct ClientEditView: View {
    let clientID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var emergencyContact = ""
    @State private var emergencyPhone = ""
    @State private var notes = ""
    @State private var isActive = true

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    private var isNew: Bool { clientID == nil }

    private var existingClient: Client? {
        guard let clientID else { return nil }
        return modelContext.model(for: clientID) as? Client
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
            }

            Section("Contact") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }

            Section("Emergency Contact") {
                TextField("Contact Name", text: $emergencyContact)
                TextField("Contact Phone", text: $emergencyPhone)
                    .keyboardType(.phonePad)
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
            }

            Section {
                Toggle("Active", isOn: $isActive)
            }

            Section {
                Button(isNew ? "Add Client" : "Save Changes") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty
                    && lastName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle(isNew ? "New Client" : "Edit Client")
        .toast(isPresented: $showToast, message: toastMessage, isError: toastIsError)
        .onAppear(perform: loadExisting)
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
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        guard !trimmedFirst.isEmpty || !trimmedLast.isEmpty else { return }

        if let client = existingClient {
            client.firstName = trimmedFirst
            client.lastName = trimmedLast
            client.email = email
            client.phone = phone
            client.emergencyContact = emergencyContact
            client.emergencyPhone = emergencyPhone
            client.notes = notes
            client.isActive = isActive
            BarnIOLogger.info("Updating client name=\(trimmedFirst) \(trimmedLast)")
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
            BarnIOLogger.info("Creating client name=\(trimmedFirst) \(trimmedLast)")
        }

        modelContext.saveWithLogging()
        toastMessage = isNew ? "Client added" : "Client updated"
        toastIsError = false
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}
