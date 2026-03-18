import SwiftUI
import SwiftData

struct ReminderEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var horses: [Horse]

    let reminderID: PersistentIdentifier?

    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate: Date = .now
    @State private var frequency: ReminderFrequency = .once
    @State private var isCompleted = false
    @State private var selectedHorseID: PersistentIdentifier?

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    private var isNew: Bool { reminderID == nil }
    private var existingReminder: Reminder? {
        guard let id = reminderID else { return nil }
        return modelContext.model(for: id) as? Reminder
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $title)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)

                Picker("Frequency", selection: $frequency) {
                    ForEach(ReminderFrequency.allCases) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }

                Toggle("Completed", isOn: $isCompleted)
            }

            Section("Horse") {
                Picker("Assign Horse", selection: $selectedHorseID) {
                    Text("None").tag(nil as PersistentIdentifier?)
                    ForEach(horses) { horse in
                        Text(horse.name).tag(horse.persistentModelID as PersistentIdentifier?)
                    }
                }
            }
        }
        .navigationTitle(isNew ? "New Reminder" : "Edit Reminder")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    save()
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: loadExisting)
        .toast(isPresented: $showToast, message: toastMessage, isError: toastIsError)
    }

    private func loadExisting() {
        guard let reminder = existingReminder else { return }
        title = reminder.title
        notes = reminder.notes
        dueDate = reminder.dueDate
        frequency = reminder.frequency
        isCompleted = reminder.isCompleted
        selectedHorseID = reminder.horse?.persistentModelID
    }

    private func save() {
        let reminder: Reminder
        if let existing = existingReminder {
            reminder = existing
        } else {
            reminder = Reminder()
            modelContext.insert(reminder)
        }

        reminder.title = title.trimmingCharacters(in: .whitespaces)
        reminder.notes = notes.trimmingCharacters(in: .whitespaces)
        reminder.dueDate = dueDate
        reminder.frequency = frequency
        reminder.isCompleted = isCompleted

        if let horseID = selectedHorseID {
            reminder.horse = modelContext.model(for: horseID) as? Horse
        } else {
            reminder.horse = nil
        }

        modelContext.saveWithLogging()

        toastMessage = isNew ? "Reminder added" : "Reminder updated"
        toastIsError = false
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}
