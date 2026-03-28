import SwiftUI
import SwiftData

struct LessonEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let lessonID: PersistentIdentifier?

    @State private var date: Date = .now
    @State private var duration: Int = 60
    @State private var lessonType: LessonType = .privateLesson
    @State private var notes = ""
    @State private var cost: Double = 0
    @State private var isPaid = false
    @State private var frequency: ReminderFrequency = .once
    @State private var nextDate: Date? = nil
    @State private var hasNextDate = false
    @State private var selectedHorseID: PersistentIdentifier?
    @State private var selectedClientID: PersistentIdentifier?

    @State private var toast = ToastState()

    private var isNew: Bool { lessonID == nil }
    private var existingLesson: Lesson? { modelContext.existingModel(for: lessonID) }

    private static let durations = [30, 45, 60, 90, 120]

    var body: some View {
        Form {
            Section("Schedule") {
                DatePicker("Date & Time", selection: $date)
                Picker("Duration", selection: $duration) {
                    ForEach(Self.durations, id: \.self) { min in
                        Text("\(min) min").tag(min)
                    }
                }
                Picker("Lesson Type", selection: $lessonType) {
                    ForEach(LessonType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

            Section("Recurring") {
                Picker("Frequency", selection: $frequency) {
                    ForEach(ReminderFrequency.allCases) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }
                Toggle("Set Next Date", isOn: $hasNextDate)
                if hasNextDate {
                    DatePicker("Next Date", selection: Binding(
                        get: { nextDate ?? date },
                        set: { nextDate = $0 }
                    ))
                }
            }

            Section("Payment") {
                CurrencyField(label: "Cost", value: $cost)
                Toggle("Paid", isOn: $isPaid)
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            HorsePickerSection(selectedHorseID: $selectedHorseID)
            ClientPickerSection(selectedClientID: $selectedClientID)
        }
        .navigationTitle(isNew ? "New Lesson" : "Edit Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    save()
                }
            }
        }
        .task { loadExisting() }
        .toast(toast)
    }

    private func loadExisting() {
        guard let lesson = existingLesson else { return }
        date = lesson.date
        duration = lesson.duration
        lessonType = lesson.lessonType
        notes = lesson.notes
        cost = lesson.cost
        isPaid = lesson.isPaid
        frequency = lesson.frequency
        nextDate = lesson.nextDate
        hasNextDate = lesson.nextDate != nil
        selectedHorseID = lesson.horse?.persistentModelID
        selectedClientID = lesson.client?.persistentModelID
    }

    private func save() {
        let lesson: Lesson
        if let existing = existingLesson {
            lesson = existing
        } else {
            lesson = Lesson()
            modelContext.insert(lesson)
        }

        lesson.date = date
        lesson.duration = duration
        lesson.lessonType = lessonType
        lesson.notes = notes.trimmingCharacters(in: .whitespaces)
        lesson.cost = cost
        lesson.isPaid = isPaid
        lesson.frequency = frequency
        lesson.nextDate = hasNextDate ? (nextDate ?? date) : nil

        if let horseID = selectedHorseID {
            lesson.horse = modelContext.model(for: horseID) as? Horse
        } else {
            lesson.horse = nil
        }

        if let clientID = selectedClientID {
            lesson.client = modelContext.model(for: clientID) as? Client
        } else {
            lesson.client = nil
        }

        modelContext.saveWithLogging()
        toast.showAndDismiss(isNew ? "Lesson added" : "Lesson updated", dismiss: dismiss)
    }
}
