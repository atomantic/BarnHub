import SwiftUI
import SwiftData

struct ReminderEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationService.self) private var notificationService

    let reminderID: PersistentIdentifier?

    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate: Date = .now
    @State private var frequency: ReminderFrequency = .once
    @State private var isCompleted = false
    @State private var selectedHorseID: PersistentIdentifier?

    @State private var toast = ToastState()

    private var isNew: Bool { reminderID == nil }
    private var existingReminder: Reminder? { modelContext.existingModel(for: reminderID) }
    private var navigationTitleKey: LocalizedStringKey { isNew ? "New Reminder" : "Edit Reminder" }

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

            HorsePickerSection(selectedHorseID: $selectedHorseID)
        }
        .navigationTitle(navigationTitleKey)
        .inlineNavTitle()
        #if os(macOS)
        .formStyle(.grouped)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    save()
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .task { loadExisting() }
        .toast(toast)
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
        notificationService.scheduleReminder(reminder)
        toast.showAndDismiss(isNew ? appLocalized("Reminder added") : appLocalized("Reminder updated"), dismiss: dismiss)
    }
}
