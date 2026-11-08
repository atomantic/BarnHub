import SwiftUI
import SwiftData

struct LessonListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(sort: \Lesson.date, order: .reverse) private var allLessons: [Lesson]

    @State private var showUpcomingOnly = false

    private var displayedLessons: [Lesson] {
        if showUpcomingOnly {
            // Each lesson's next date is worked out once, not on every comparison.
            return allLessons
                .compactMap { lesson in lesson.scheduledDate().map { (lesson, $0) } }
                .sorted { $0.1 < $1.1 }
                .map(\.0)
        }
        return allLessons
    }

    var body: some View {
        let displayedLessons = self.displayedLessons  // once per render
        return Group {
            if displayedLessons.isEmpty {
                EmptyStateView(
                    icon: "book.fill",
                    title: showUpcomingOnly ? "No Upcoming Lessons" : "No Lessons",
                    subtitle: showUpcomingOnly
                        ? "Lessons with a next date will appear here."
                        : "Add your first lesson to get started."
                )
            } else {
                List {
                    ForEach(displayedLessons) { lesson in
                        Button {
                            router.navigate(to: BarnRoute.lessonEdit(lesson.persistentModelID))
                        } label: {
                            lessonRow(lesson)
                        }
                        .foregroundStyle(.primary)  // not .tint(.primary): a hierarchical tint can loop endlessly on Mac Catalyst
                    }
                    .onDelete(perform: deleteLessons)
                }
            }
        }
        .navigationTitle("Lessons")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: BarnRoute.lessonEdit(nil))
                } label: {
                    Label("Add Lesson", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .leadingBar) {
                // A menu with a title + symbol adapts to vertical bars and the
                // overflow menu on iPhone Duo; a fixed-width segmented control can't.
                Menu {
                    Picker("Filter", selection: $showUpcomingOnly) {
                        Text("All").tag(false)
                        Text("Upcoming").tag(true)
                    }
                } label: {
                    Label("Filter", systemImage: showUpcomingOnly
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.client?.fullName ?? appLocalized("No Client", comment: "Lesson row title when the lesson has no client"))
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
                // A recurring lesson shows its next occurrence, not its first date.
                let displayDate = lesson.scheduledDate() ?? lesson.date
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
