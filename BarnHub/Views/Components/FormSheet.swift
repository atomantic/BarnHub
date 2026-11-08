import SwiftUI

/// Shows an add/edit form route as a sheet with a Cancel button, used on the
/// Mac and at regular width instead of pushing the form onto the tab's stack.
struct FormSheet: View {
    let form: Router.PresentedForm
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        // Its own path, so screens opened from inside the form (the paywall from a
        // Pro lock) push here, in front of the user, instead of onto the tab
        // stack hidden behind the sheet (#46).
        NavigationStack(path: $router.formPath) {
            content
                .withRouteDestinations()
                .tint(.barnGreen)  // sheets don't inherit the root's tint
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 600, idealWidth: 680, minHeight: 520, idealHeight: 680)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if let route = form.route.base as? HorseRoute {
            route.destination
        } else if let route = form.route.base as? ClientRoute {
            route.destination
        } else if let route = form.route.base as? AccountingRoute {
            route.destination
        } else if let route = form.route.base as? BarnRoute {
            route.destination
        }
    }
}

// MARK: - App environment for sheets

/// The app's shared `@Observable` objects, handed to sheets presented from the root view.
struct AppEnvironmentObjects {
    let router: Router
    let storeService: StoreService
    let appearanceManager: AppearanceManager
    let notificationService: NotificationService
    let syncMonitor: SyncMonitor
}

extension View {
    /// Passes the app's shared objects into a sheet presented from the root view.
    /// Mac Catalyst doesn't carry the window's @Observable environment into these
    /// sheets, and a view reading a missing object traps.
    func withAppEnvironment(_ objects: AppEnvironmentObjects) -> some View {
        self
            .environment(objects.router)
            .environment(objects.storeService)
            .environment(objects.appearanceManager)
            .environment(objects.notificationService)
            .environment(objects.syncMonitor)
    }
}
