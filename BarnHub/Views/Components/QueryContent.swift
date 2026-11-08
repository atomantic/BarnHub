import SwiftUI
import SwiftData

/// Runs a `@Query` built from `descriptor` and hands the results to `content`.
///
/// Lets a screen whose filters live in `@State` fetch only the matching rows: the
/// parent passes a descriptor built from its current filters, and the query is
/// rebuilt whenever they change, instead of loading the whole table and
/// filtering in Swift on every render (#32). Results still update live on every
/// save and CloudKit import, like any `@Query`.
struct QueryContent<Model: PersistentModel, Content: View>: View {
    @Query private var results: [Model]
    private let content: ([Model]) -> Content

    init(_ descriptor: FetchDescriptor<Model>, @ViewBuilder content: @escaping ([Model]) -> Content) {
        _results = Query(descriptor)
        self.content = content
    }

    var body: some View {
        content(results)
    }
}
