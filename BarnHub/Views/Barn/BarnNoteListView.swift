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

    private var groupedNotes: [(key: String, notes: [BarnNote])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredNotes) { note -> String in
            if calendar.isDateInToday(note.date) {
                return "Today"
            } else if calendar.isDateInYesterday(note.date) {
                return "Yesterday"
            } else {
                return note.date.formatted(.dateTime.month(.wide).day().year())
            }
        }
        // Sort groups: Today first, Yesterday second, then by date descending
        return grouped.sorted { a, b in
            if a.key == "Today" { return true }
            if b.key == "Today" { return false }
            if a.key == "Yesterday" { return true }
            if b.key == "Yesterday" { return false }
            let dateA = a.value.first?.date ?? .distantPast
            let dateB = b.value.first?.date ?? .distantPast
            return dateA > dateB
        }.map { (key: $0.key, notes: $0.value) }
    }

    var body: some View {
        List {
            categoryFilter

            if filteredNotes.isEmpty {
                EmptyStateView(
                    icon: "note.text",
                    title: "No Barn Notes",
                    subtitle: "Tap + to log a barn note."
                )
            } else {
                ForEach(groupedNotes, id: \.key) { group in
                    Section(group.key) {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: BarnRoute.barnNoteEdit(nil))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .toast(toast)
    }

    private var categoryFilter: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: "All", isSelected: selectedCategory == nil) {
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
                    Text(note.date.formatted(.dateTime.hour().minute()))
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
        toast.show("Note deleted")
    }
}
