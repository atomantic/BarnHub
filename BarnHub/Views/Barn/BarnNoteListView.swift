import SwiftUI
import SwiftData

struct BarnNoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(sort: \BarnNote.date, order: .reverse) private var notes: [BarnNote]

    @State private var selectedCategory: BarnNoteCategory?
    @State private var toast = ToastState()

    private var filteredNotes: [BarnNote] {
        guard let category = selectedCategory else { return notes }
        return notes.filter { $0.category == category }
    }

    private enum DateGroup: Hashable, Comparable {
        case today, yesterday, date(Date)

        static func < (lhs: DateGroup, rhs: DateGroup) -> Bool {
            switch (lhs, rhs) {
            case (.today, .today): return false
            case (.today, _): return true
            case (_, .today): return false
            case (.yesterday, .yesterday): return false
            case (.yesterday, _): return true
            case (_, .yesterday): return false
            case (.date(let a), .date(let b)): return a > b
            }
        }

        var title: String {
            switch self {
            case .today: return appLocalized("Today")
            case .yesterday: return appLocalized("Yesterday")
            case .date(let d): return d.formatted(.dateTime.month(.wide).day().year())
            }
        }
    }

    private var groupedNotes: [(key: DateGroup, notes: [BarnNote])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredNotes) { note -> DateGroup in
            if calendar.isDateInToday(note.date) {
                return .today
            } else if calendar.isDateInYesterday(note.date) {
                return .yesterday
            } else {
                return .date(calendar.startOfDay(for: note.date))
            }
        }
        return grouped.sorted { $0.key < $1.key }.map { (key: $0.key, notes: $0.value) }
    }

    var body: some View {
        let groupedNotes = self.groupedNotes  // filtered and grouped once per render
        return List {
            categoryFilter

            if groupedNotes.isEmpty {
                EmptyStateView(
                    icon: "note.text",
                    title: "No Barn Notes",
                    subtitle: "Tap + to log a barn note."
                )
            } else {
                ForEach(groupedNotes, id: \.key) { group in
                    Section(group.key.title) {
                        ForEach(group.notes, id: \.persistentModelID) { note in
                            NavigationLink(value: BarnRoute.barnNoteEdit(note.persistentModelID)) {
                                noteRow(note)
                            }
                        }
                        .onDelete { offsets in
                            deleteNotes(from: group.notes, at: offsets)
                        }
                    }
                }
            }
        }
        .navigationTitle("Barn Notes")
        .inlineNavTitle()
        .prioritizedToolbarItem(.high, placement: .primaryAction) {
            Button {
                router.navigate(to: BarnRoute.barnNoteEdit(nil))
            } label: {
                Label("New Note", systemImage: "plus")
            }
        }
        .toast(toast)
    }

    private var categoryFilter: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: appLocalized("All", comment: "Filter chip label"), isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(BarnNoteCategory.allCases) { category in
                        filterChip(
                            label: category.displayName,
                            icon: category.icon,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func filterChip(label: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? Color.barnGreen : Color.barnCardBackground)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func noteRow(_ note: BarnNote) -> some View {
        HStack(spacing: 10) {
            Image(systemName: note.category.icon)
                .font(.caption)
                .foregroundStyle(.barnGreen)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.content)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(note.date, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let horse = note.horse {
                        Label(horse.name, systemImage: "figure.equestrian.sports")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(note.category.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.barnGreen.opacity(0.15)))
                        .foregroundStyle(.barnGreen)
                }
            }
        }
    }

    private func deleteNotes(from groupNotes: [BarnNote], at offsets: IndexSet) {
        for index in offsets {
            modelContext.deleteWithLogging(groupNotes[index])
        }
        toast.show(appLocalized("Note deleted"))
    }
}
