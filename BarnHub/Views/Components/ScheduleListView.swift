import SwiftUI
import SwiftData

struct ScheduleListView<Record: Identifiable>: View {
    @Environment(Router.self) private var router

    let records: [Record]
    let horseName: (Record) -> String
    let horseID: (Record) -> PersistentIdentifier?
    let providerName: (Record) -> String
    let description: (Record) -> String
    let nextDueDate: (Record) -> Date?
    let navigationTitle: LocalizedStringKey
    let emptyIcon: String
    let emptyTitle: LocalizedStringKey
    let emptySubtitle: LocalizedStringKey
    let addRoute: BarnRoute
    let addLabel: LocalizedStringKey

    var body: some View {
        List {
            if records.isEmpty {
                EmptyStateView(
                    icon: emptyIcon,
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
            } else {
                ForEach(records) { record in
                    Button {
                        guard let id = horseID(record) else { return }
                        router.navigate(to: HorseRoute.detail(id))
                    } label: {
                        ScheduleRecordRow(
                            horseName: horseName(record),
                            providerName: providerName(record),
                            description: description(record),
                            nextDueDate: nextDueDate(record)
                        )
                    }
                    .tint(.primary)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: addRoute) {
                    Label(addLabel, systemImage: "plus")
                }
            }
        }
    }
}
