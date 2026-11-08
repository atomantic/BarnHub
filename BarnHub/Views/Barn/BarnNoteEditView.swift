import SwiftUI
import SwiftData

struct BarnNoteEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let noteID: PersistentIdentifier?

    @State private var content = ""
    @State private var date: Date = .now
    @State private var category: BarnNoteCategory = .general
    @State private var selectedHorseID: PersistentIdentifier?

    @State private var toast = ToastState()

    private var isNew: Bool { noteID == nil }
    private var existingNote: BarnNote? { modelContext.existingModel(for: noteID) }
    /// Editing a record that was deleted meanwhile (here or on another device).
    private var wasDeletedElsewhere: Bool { modelContext.isDeletedRecord(noteID, as: BarnNote.self) }
    private var navigationTitleKey: LocalizedStringKey { isNew ? "New Note" : "Edit Note" }

    var body: some View {
        Form {
            Section("Note") {
                TextField("What happened at the barn?", text: $content, axis: .vertical)
                    .lineLimit(4...12)
            }

            Section("Details") {
                DatePicker("Date", selection: $date)

                Picker("Category", selection: $category) {
                    ForEach(BarnNoteCategory.allCases) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
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
            ToolbarItem(placement: .pinnedConfirmation) {
                Button("Save") {
                    save()
                }
                .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .task { loadExisting() }
        .deletedRecordNotice(wasDeletedElsewhere)
        .toast(toast)
    }

    private func loadExisting() {
        guard let note = existingNote else { return }
        content = note.content
        date = note.date
        category = note.category
        selectedHorseID = note.horse?.persistentModelID
    }

    private func save() {
        // Never insert a replacement for a record deleted while the form was open.
        guard !wasDeletedElsewhere else {
            toast.showAndDismiss(appLocalized("This item was deleted", comment: "Toast when saving a record that was deleted elsewhere"), isError: true, dismiss: dismiss)
            return
        }
        let note: BarnNote
        if let existing = existingNote {
            note = existing
        } else {
            note = BarnNote()
            modelContext.insert(note)
        }

        note.content = content.trimmingCharacters(in: .whitespaces)
        note.date = date
        note.category = category

        if let horseID = selectedHorseID {
            note.horse = modelContext.existingModel(for: horseID)
        } else {
            note.horse = nil
        }

        modelContext.saveWithLogging()
        toast.showAndDismiss(isNew ? appLocalized("Note added") : appLocalized("Note updated"), dismiss: dismiss)
    }
}
