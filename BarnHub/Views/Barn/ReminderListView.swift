import SwiftUI
import SwiftData

struct ReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(NotificationService.self) private var notificationService

    @Query(sort: \Reminder.dueDate) private var reminders: [Reminder]

    @State private var showCompleted = false
    @State private var showToast = false
    @State private var toastMessage = ""

    private var categorizedReminders: (overdue: [Reminder], upcoming: [Reminder], completed: [Reminder]) {
        var overdue: [Reminder] = []
        var upcoming: [Reminder] = []
        var completed: [Reminder] = []
        for reminder in reminders {
            if reminder.isCompleted {
                completed.append(reminder)
            } else if reminder.dueDate.isOverdue {
                overdue.append(reminder)
            } else {
                upcoming.append(reminder)
            }
        }
        return (overdue, upcoming, completed)
    }

    var body: some View {
        let categorized = categorizedReminders
        List {
            if !categorized.overdue.isEmpty {
                Section("Overdue") {
                    ForEach(categorized.overdue) { reminder in
                        reminderRow(reminder, isOverdue: true)
                    }
                }
            }

            Section("Upcoming") {
                if categorized.upcoming.isEmpty && categorized.overdue.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "No Reminders",
                        subtitle: "Tap + to create a reminder."
                    )
                } else {
                    ForEach(categorized.upcoming) { reminder in
                        reminderRow(reminder, isOverdue: false)
                    }
                }
            }

            if showCompleted && !categorized.completed.isEmpty {
                Section("Completed") {
                    ForEach(categorized.completed) { reminder in
                        reminderRow(reminder, isOverdue: false)
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: BarnRoute.reminderEdit(nil))
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Toggle("Show Completed", isOn: $showCompleted)
            }
        }
        .toast(isPresented: $showToast, message: toastMessage)
    }

    private func reminderRow(_ reminder: Reminder, isOverdue: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleCompletion(reminder)
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(reminder.isCompleted ? .green : (isOverdue ? .red : .secondary))
                    .font(.title3)
            }
            .buttonStyle(.plain)

            NavigationLink(value: BarnRoute.reminderEdit(reminder.persistentModelID)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                        .font(.headline)
                        .strikethrough(reminder.isCompleted)
                    HStack(spacing: 8) {
                        Text(reminder.dueDate.shortFormatted)
                            .font(.caption)
                            .foregroundStyle(isOverdue ? .red : .secondary)
                        if let horse = reminder.horse {
                            Text(horse.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if reminder.frequency != .once {
                            Text(reminder.frequency.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.blue.opacity(0.15)))
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
    }

    private func toggleCompletion(_ reminder: Reminder) {
        reminder.isCompleted.toggle()
        modelContext.saveWithLogging()
        notificationService.scheduleReminder(reminder)
        toastMessage = reminder.isCompleted ? "Marked complete" : "Marked incomplete"
        showToast = true
    }
}
