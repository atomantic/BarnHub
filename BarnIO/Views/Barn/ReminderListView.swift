import SwiftUI
import SwiftData

struct ReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(sort: \Reminder.dueDate) private var reminders: [Reminder]

    @State private var showCompleted = false
    @State private var showToast = false
    @State private var toastMessage = ""

    private var overdueReminders: [Reminder] {
        reminders.filter { !$0.isCompleted && $0.dueDate.isOverdue }
    }

    private var upcomingReminders: [Reminder] {
        reminders.filter { !$0.isCompleted && !$0.dueDate.isOverdue }
    }

    private var completedReminders: [Reminder] {
        reminders.filter(\.isCompleted)
    }

    var body: some View {
        List {
            if !overdueReminders.isEmpty {
                Section("Overdue") {
                    ForEach(overdueReminders) { reminder in
                        reminderRow(reminder, isOverdue: true)
                    }
                }
            }

            Section("Upcoming") {
                if upcomingReminders.isEmpty && overdueReminders.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "No Reminders",
                        subtitle: "Tap + to create a reminder."
                    )
                } else {
                    ForEach(upcomingReminders) { reminder in
                        reminderRow(reminder, isOverdue: false)
                    }
                }
            }

            if showCompleted && !completedReminders.isEmpty {
                Section("Completed") {
                    ForEach(completedReminders) { reminder in
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
        .navigationDestination(for: BarnRoute.self) { route in
            switch route {
            case .reminderEdit(let id):
                ReminderEditView(reminderID: id)
            default:
                EmptyView()
            }
        }
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
        toastMessage = reminder.isCompleted ? "Marked complete" : "Marked incomplete"
        showToast = true
    }
}
