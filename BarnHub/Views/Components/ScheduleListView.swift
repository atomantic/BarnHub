import SwiftUI
import SwiftData

/// A list of vet, farrier or dentist records with a next due date. Like Home,
/// the calendar and notifications, it leaves out a due date that a newer record
/// for the same horse has superseded (#50).
struct ScheduleListView<Record: HorseCareRecord>: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncMonitor.self) private var syncMonitor
    /// Bumped on every save and CloudKit import, so the newest-record map (not a
    /// `@Query`) is rebuilt only when the data changes, not on every render.
    @State private var dataVersion = 0
    @State private var newestCare = NewestCareRecordsCache()

    /// Records with a next due date, in display order.
    let records: [Record]
    /// Which kind's newest records supersede these.
    let newest: KeyPath<NewestCareRecords, [PersistentIdentifier: SupersedeKey]>
    let providerName: (Record) -> String
    let description: (Record) -> String
    let navigationTitle: LocalizedStringKey
    let emptyIcon: String
    let emptyTitle: LocalizedStringKey
    let emptySubtitle: LocalizedStringKey
    let addRoute: BarnRoute
    let addLabel: LocalizedStringKey

    var body: some View {
        let current = NewestCareRecords.current(
            records,
            newest: newestCare.value(version: dataVersion, context: modelContext)[keyPath: newest]
        )
        Group {
            if current.isEmpty {
                EmptyStateView(
                    icon: emptyIcon,
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
            } else {
                List {
                    ForEach(current) { record in
                        Button {
                            guard let id = record.horse?.persistentModelID else { return }
                            router.navigate(to: HorseRoute.detail(id))
                        } label: {
                            ScheduleRecordRow(
                                horseName: record.horse?.name ?? appLocalized("Unknown Horse", comment: "Fallback horse name"),
                                providerName: providerName(record),
                                description: description(record),
                                nextDueDate: record.nextDueDate
                            )
                        }
                        .foregroundStyle(.primary)  // not .tint(.primary): a hierarchical tint can loop endlessly on Mac Catalyst
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: addRoute)
                } label: {
                    Label(addLabel, systemImage: "plus")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave).receive(on: RunLoop.main)) { _ in
            dataVersion &+= 1
        }
        .onChange(of: syncMonitor.lastSuccessfulSync) { dataVersion &+= 1 }
    }
}
