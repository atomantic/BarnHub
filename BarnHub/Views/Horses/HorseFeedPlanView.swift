import SwiftUI
import SwiftData

struct HorseFeedPlanView: View {
    let horseID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @State private var showDeleteConfirmation = false
    @State private var entryToDelete: FeedPlanEntry?
    @State private var showToast = false
    @State private var toastMessage = ""

    private var horse: Horse? {
        modelContext.model(for: horseID) as? Horse
    }

    private var entries: [FeedPlanEntry] {
        (horse?.feedPlanEntries ?? []).sorted {
            if $0.feedTime != $1.feedTime { return $0.feedTime < $1.feedTime }
            return ($0.product?.name ?? "") < ($1.product?.name ?? "")
        }
    }

    private func entriesFor(_ time: FeedTime) -> [FeedPlanEntry] {
        entries.filter { $0.feedTime == time }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                EmptyStateView(
                    icon: "fork.knife",
                    title: "No Feed Plan",
                    subtitle: "Tap + to add feed items to this horse's daily plan."
                )
            } else {
                ForEach(FeedTime.allCases) { time in
                    let timeEntries = entriesFor(time)
                    if !timeEntries.isEmpty {
                        Section {
                            ForEach(timeEntries, id: \.persistentModelID) { entry in
                                feedEntryRow(entry)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Delete", role: .destructive) {
                                            entryToDelete = entry
                                            showDeleteConfirmation = true
                                        }
                                        Button("Edit") {
                                            router.navigate(to: HorseRoute.editFeedEntry(horseID, entry.persistentModelID))
                                        }
                                        .tint(.barnGreen)
                                    }
                            }
                        } header: {
                            Label(time.displayName, systemImage: time.icon)
                        }
                    }
                }

                if !legacyNotes.isEmpty {
                    Section("Notes") {
                        Text(legacyNotes)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Feed Plan")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: HorseRoute.editFeedEntry(horseID, nil))
                } label: {
                    Image(systemName: "plus")
                }
            }
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

    private var legacyNotes: String {
        horse?.feedingSchedule ?? ""
    }

    private func feedEntryRow(_ entry: FeedPlanEntry) -> some View {
        HStack(spacing: 12) {
            if let photoData = entry.product?.photoData, let image = Image(photoData: photoData) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.barnGreen)
                    .font(.title3)
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.headline)
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
}
