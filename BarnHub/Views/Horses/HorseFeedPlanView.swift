import SwiftUI
import SwiftData

struct HorseFeedPlanView: View {
    let horseID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @State private var sheetState: SheetState?
    @State private var showDeleteConfirmation = false
    @State private var entryToDelete: FeedPlanEntry?
    @State private var showToast = false
    @State private var toastMessage = ""

    private enum SheetState: Identifiable {
        case edit(PersistentIdentifier)
        case add(FeedTime)

        var id: String {
            switch self {
            case .edit(let pid): return "edit-\(pid.hashValue)"
            case .add(let time): return "add-\(time.rawValue)"
            }
        }
    }

    private var horse: Horse? {
        modelContext.existingModel(for: horseID)
    }

    private var entries: [FeedPlanEntry] {
        (horse?.feedPlanEntries ?? []).sorted {
            if $0.feedTime != $1.feedTime { return $0.feedTime < $1.feedTime }
            return ($0.product?.name ?? "") < ($1.product?.name ?? "")
        }
    }

    private var legacyNotes: String {
        horse?.feedingSchedule ?? ""
    }

    private func entriesFor(_ time: FeedTime) -> [FeedPlanEntry] {
        entries.filter { $0.feedTime == time }
    }

    private var useWideLayout: Bool {
        #if os(macOS)
        return true
        #else
        return sizeClass == .regular
        #endif
    }

    var body: some View {
        Group {
            if useWideLayout {
                wideLayout
            } else {
                compactLayout
            }
        }
        .navigationTitle("Feed Plan")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheetState = .add(.morning)
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $sheetState) { state in
            NavigationStack {
                switch state {
                case .edit(let pid):
                    FeedPlanEntryEditView(horseID: horseID, entryID: pid)
                case .add(let time):
                    FeedPlanEntryEditView(horseID: horseID, entryID: nil, initialTime: time)
                }
            }
            #if os(macOS)
            .frame(minWidth: 480, idealWidth: 560, minHeight: 560, idealHeight: 640)
            #endif
        }
        .overlay {
            ConfirmationDialog(
                isPresented: $showDeleteConfirmation,
                title: "Remove Feed Item",
                message: "Remove \"\(entryToDelete?.summary ?? "this item")\" from the feed plan?",
                confirmTitle: "Remove",
                confirmRole: .destructive
            ) {
                guard let entry = entryToDelete else { return }
                modelContext.deleteWithLogging(entry)
                toastMessage = appLocalized("Feed item removed")
                showToast = true
                entryToDelete = nil
            }
        }
        .toast(isPresented: $showToast, message: toastMessage)
    }

    // MARK: - Compact (iPhone) Layout

    private var compactLayout: some View {
        Group {
            if entries.isEmpty && legacyNotes.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(FeedTime.allCases) { time in
                        timeSection(time)
                    }

                    if !legacyNotes.isEmpty {
                        Section("Notes") {
                            Text(legacyNotes)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func timeSection(_ time: FeedTime) -> some View {
        Section {
            let timeEntries = entriesFor(time)
            if timeEntries.isEmpty {
                Button {
                    sheetState = .add(time)
                } label: {
                    Label("Add Feed Item", systemImage: "plus.circle.fill")
                        .foregroundStyle(.barnGreen)
                }
            } else {
                ForEach(timeEntries, id: \.persistentModelID) { entry in
                    Button {
                        sheetState = .edit(entry.persistentModelID)
                    } label: {
                        feedEntryRow(entry)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            entryToDelete = entry
                            showDeleteConfirmation = true
                        }
                    }
                }

                Button {
                    sheetState = .add(time)
                } label: {
                    Label("Add Feed Item", systemImage: "plus.circle.fill")
                        .foregroundStyle(.barnGreen)
                        .font(.subheadline)
                }
            }
        } header: {
            Label(time.displayName, systemImage: time.icon)
        }
    }

    // MARK: - Wide (iPad/macOS) Layout

    private var wideLayout: some View {
        Group {
            if entries.isEmpty && legacyNotes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(FeedTime.allCases) { time in
                            timeColumn(time)
                        }
                    }
                    .padding()

                    if !legacyNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(legacyNotes)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private func timeColumn(_ time: FeedTime) -> some View {
        let timeEntries = entriesFor(time)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(time.displayName, systemImage: time.icon)
                    .font(.headline)
                    .foregroundStyle(.barnGreen)
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(timeEntries, id: \.persistentModelID) { entry in
                    Button {
                        sheetState = .edit(entry.persistentModelID)
                    } label: {
                        feedEntryCard(entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit") {
                            sheetState = .edit(entry.persistentModelID)
                        }
                        Button("Delete", role: .destructive) {
                            entryToDelete = entry
                            showDeleteConfirmation = true
                        }
                    }
                }

                Button {
                    sheetState = .add(time)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Feed Item")
                            .font(.subheadline)
                        Spacer()
                    }
                    .foregroundStyle(.barnGreen)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.barnGreen.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4])))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
    }

    private func feedEntryCard(_ entry: FeedPlanEntry) -> some View {
        HStack(spacing: 12) {
            productImage(entry)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if let brand = entry.product?.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !entry.assignedPerson.isEmpty {
                    Text(entry.assignedPerson)
                        .font(.caption)
                        .foregroundStyle(.barnGreen)
                }
            }

            Spacer(minLength: 0)

            if !entry.notes.isEmpty {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
    }

    private func feedEntryRow(_ entry: FeedPlanEntry) -> some View {
        HStack(spacing: 12) {
            productImage(entry)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let brand = entry.product?.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !entry.assignedPerson.isEmpty {
                    Text(entry.assignedPerson)
                        .font(.caption)
                        .foregroundStyle(.barnGreen)
                }
            }

            Spacer()

            if !entry.notes.isEmpty {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private func productImage(_ entry: FeedPlanEntry) -> some View {
        if let photoData = entry.product?.photoData, let image = Image(photoData: photoData) {
            image
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.barnGreen)
                .font(.title3)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                icon: "fork.knife",
                title: "No Feed Plan",
                subtitle: "Tap + to add feed items to this horse's daily plan."
            )
            HStack(spacing: 12) {
                ForEach(FeedTime.allCases) { time in
                    Button {
                        sheetState = .add(time)
                    } label: {
                        Label(time.displayName, systemImage: time.icon)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.barnGreen.opacity(0.15)))
                            .foregroundStyle(.barnGreen)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}
