import SwiftUI
import SwiftData

struct LessonListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(sort: \Lesson.date, order: .reverse) private var allLessons: [Lesson]

    @State private var showUpcomingOnly = false

    private var displayedLessons: [Lesson] {
        if showUpcomingOnly {
            return allLessons
                .filter { $0.nextDate != nil }
                .sorted { ($0.nextDate ?? .distantFuture) < ($1.nextDate ?? .distantFuture) }
        }
        return allLessons
    }

    var body: some View {
        List {
            if displayedLessons.isEmpty {
                EmptyStateView(
                    icon: "book.fill",
                    title: showUpcomingOnly ? "No Upcoming Lessons" : "No Lessons",
                    subtitle: showUpcomingOnly
                        ? "Lessons with a next date will appear here."
                        : "Add your first lesson to get started."
                )
            } else {
                ForEach(displayedLessons) { lesson in
                    NavigationLink(value: BarnRoute.lessonEdit(lesson.persistentModelID)) {
                        lessonRow(lesson)
                    }
                }
                .onDelete(perform: deleteLessons)
            }
        }
        .navigationTitle("Lessons")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: BarnRoute.lessonEdit(nil)) {
                    Label("Add Lesson", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Picker("Filter", selection: $showUpcomingOnly) {
                    Text("All").tag(false)
                    Text("Upcoming").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.client?.fullName ?? "No Client")
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(lesson.lessonType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.barnGreen.opacity(0.15))
                        .clipShape(Capsule())
                    if let horse = lesson.horse {
                        Text(horse.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if !lesson.notes.isEmpty {
                    Text(lesson.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                let displayDate = lesson.nextDate ?? lesson.date
                Text(displayDate.shortFormatted)
                    .font(.subheadline)
                    .foregroundStyle(displayDate.isOverdue ? .red : .primary)
                Text("\(lesson.duration) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(lesson.cost.asCurrency)
                        .font(.caption)
                    Image(systemName: lesson.isPaid ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(lesson.isPaid ? Color.barnGreen : .orange)
                        .accessibilityLabel(lesson.isPaid ? "Paid" : "Unpaid")
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func deleteLessons(at offsets: IndexSet) {
        for index in offsets {
            modelContext.deleteWithLogging(displayedLessons[index])
        }
    }
}
