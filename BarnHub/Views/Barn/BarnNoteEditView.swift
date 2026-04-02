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
        .navigationTitle(isNew ? "New Note" : "Edit Note")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    save()
                }
                .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .task { loadExisting() }
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
            note.horse = modelContext.model(for: horseID) as? Horse
        } else {
            note.horse = nil
        }

        modelContext.saveWithLogging()
        toast.showAndDismiss(isNew ? "Note added" : "Note updated", dismiss: dismiss)
    }
}
