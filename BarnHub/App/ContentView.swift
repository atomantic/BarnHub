import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(Router.self) private var router
    @Environment(SyncMonitor.self) private var syncMonitor
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @Environment(NotificationService.self) private var notificationService
    @Environment(StoreService.self) private var storeService
    @Environment(AppearanceManager.self) private var appearanceManager
    @Environment(\.modelContext) private var modelContext
    #if os(macOS) && DEBUG
    @Environment(\.openSettings) private var openSettings  // screenshot routes only
    #endif
    @AppStorage("net.shadowpuppet.BarnBook.hasCompletedFirstLaunch") private var hasCompletedFirstLaunch = false
    @State private var showFirstLaunchSheet = false
    /// The CloudKit store failed to open and the app is running on a throwaway
    /// in-memory store: nothing entered now survives a relaunch, so say so (#30).
    @State private var showStorageFailure = StorageMode.current == .inMemoryFallback
    @State private var storageRetryRequested = false
    @State private var showStorageBugReport = false

    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = NotificationDelegate.shared

    var body: some View {
        @Bindable var router = router
        Group {
            #if os(macOS)
            sidebarLayout
            #else
            if #available(iOS 18.0, *) {
                // One view hierarchy for every size: the system shows a tab bar at
                // compact width and a sidebar at regular width. Opening or closing
                // iPhone Duo (or resizing on iPad) keeps screens, sheets and
                // half-typed forms instead of rebuilding the whole tree.
                adaptiveTabLayout
            } else if sizeClass == .regular {
                sidebarLayout
            } else {
                tabBarLayout
            }
            #endif
        }
        .task {
            if !hasCompletedFirstLaunch && StorageMode.current != .inMemoryFallback {
                showFirstLaunchSheet = true
            }
            // Sample data must never schedule reminders or cancel real ones: the
            // Debug build shares BarnHub's bundle ID, and so its notifications.
            // Without attach, later sync requests have no context and do nothing.
            if StorageMode.current != .inMemorySeed {
                notificationService.attach(to: modelContext)
                notificationService.requestSync(delay: .zero)
            }
            #if DEBUG
            screenshotRouter.handleLaunchArguments()
            #endif
            routeNotificationTap()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { notificationService.requestSync() }
        }
        .onChange(of: notificationDelegate.pendingDeepLink) { routeNotificationTap() }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .sheet(item: $router.presentedForm) { form in
            FormSheet(form: form).withAppEnvironment(appEnvironment)
        }
        .onAppear { updateFormPresentation() }
        #if os(iOS)
        .onChange(of: sizeClass) { updateFormPresentation() }
        #endif
        .sheet(isPresented: $showFirstLaunchSheet) {
            FirstLaunchSheet().withAppEnvironment(appEnvironment)
        }
        .alert("Your Data Can't Be Saved", isPresented: $showStorageFailure) {
            Button("Retry") { retryStorage() }
            Button("Report a Bug") { showStorageBugReport = true }
        } message: {
            if storageRetryRequested {
                Text("To retry, quit BarnHub completely and open it again. On iPhone or iPad, swipe BarnHub away in the app switcher, then reopen it. If this keeps happening, report a bug.")
            } else {
                Text("BarnHub couldn't open its data store, so nothing you add or change now will be saved. It will be gone when the app closes.")
            }
        }
        .onChange(of: showStorageFailure) { _, isShown in
            // Blocking: the alert comes back until the app is relaunched, except
            // while the bug report is open.
            if !isShown && !showStorageBugReport {
                DispatchQueue.main.async { showStorageFailure = true }
            }
        }
        .sheet(isPresented: $showStorageBugReport, onDismiss: { showStorageFailure = true }) {
            BugReportView().withAppEnvironment(appEnvironment)
        }
    }

    /// A new store can only be opened by relaunching: quit on the Mac, and explain
    /// how to relaunch where an app can't quit itself.
    private func retryStorage() {
        #if os(macOS)
        NSApplication.shared.terminate(nil)
        #else
        storageRetryRequested = true
        #endif
    }

    /// The app's shared objects, passed into each sheet presented from this root view.
    private var appEnvironment: AppEnvironmentObjects {
        AppEnvironmentObjects(
            router: router,
            storeService: storeService,
            appearanceManager: appearanceManager,
            notificationService: notificationService,
            syncMonitor: syncMonitor
        )
    }

    /// Forms open as sheets on the Mac and in iPad-sized windows, and push on iPhone.
    private func updateFormPresentation() {
        #if os(macOS)
        router.presentsFormsAsSheets = true
        #else
        router.presentsFormsAsSheets = sizeClass == .regular
        #endif
    }

    private func handleIncomingURL(_ url: URL) {
        #if DEBUG
        if url.scheme == "barnhub", url.host() == "screenshot" {
            let page = url.pathComponents.filter { $0 != "/" }.first ?? ""
            screenshotRouter.navigate(to: page)
            return
        }
        #endif
        DeepLinkHandler.handle(url: url, router: router)
    }

    private func routeNotificationTap() {
        guard let url = notificationDelegate.consumeDeepLink() else { return }
        DeepLinkHandler.handle(url: url, router: router)
    }

    #if DEBUG
    private var screenshotRouter: ScreenshotRouter {
        #if os(macOS)
        ScreenshotRouter(router: router, modelContext: modelContext, openSettings: openSettings)
        #else
        ScreenshotRouter(router: router, modelContext: modelContext)
        #endif
    }
    #endif

    @ViewBuilder
    private var sidebarLayout: some View {
        @Bindable var router = router
        NavigationSplitView {
            SidebarView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    sidebarFooter
                }
        } detail: {
            sidebarDetailView
                .id(router.selectedTab)
        }
        .tint(.barnGreen)
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                SyncIndicatorView()
                Text(syncMonitor.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                #if os(macOS)
                // Opens the Settings window (same as ⌘,) rather than a page in this one.
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appLocalized("Settings"))
                .help(Text("Settings"))
                #else
                Button {
                    router.navigate(to: HomeRoute.settings)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appLocalized("Settings"))
                #endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    #if os(iOS)
    @available(iOS 18.0, *)
    private var adaptiveTabLayout: some View {
        @Bindable var router = router
        return TabView(selection: $router.selectedTab) {
            ForEach(Router.AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.icon, value: tab) {
                    tabStack(for: tab)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.barnGreen)
    }

    @ViewBuilder
    private var tabBarLayout: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .withRouteDestinations()
                    #if os(iOS)
                    .withNavControls(router: router, onBrandHeader: true)
                    #endif
            }
            .tabItem { Label(Router.AppTab.home.title, systemImage: Router.AppTab.home.icon) }
            .tag(Router.AppTab.home)

            NavigationStack(path: $router.horsesPath) {
                HorseListView()
                    .withRouteDestinations()
                    #if os(iOS)
                    .withNavControls(router: router)
                    #endif
            }
            .tabItem { Label(Router.AppTab.horses.title, systemImage: Router.AppTab.horses.icon) }
            .tag(Router.AppTab.horses)

            NavigationStack(path: $router.clientsPath) {
                ClientListView()
                    .withRouteDestinations()
                    #if os(iOS)
                    .withNavControls(router: router)
                    #endif
            }
            .tabItem { Label(Router.AppTab.clients.title, systemImage: Router.AppTab.clients.icon) }
            .tag(Router.AppTab.clients)

            NavigationStack(path: $router.schedulePath) {
                BarnDashboardView()
                    .withRouteDestinations()
                    #if os(iOS)
                    .withNavControls(router: router)
                    #endif
            }
            .tabItem { Label(Router.AppTab.schedule.title, systemImage: Router.AppTab.schedule.icon) }
            .tag(Router.AppTab.schedule)

            NavigationStack(path: $router.accountingPath) {
                AccountingDashboardView()
                    .withRouteDestinations()
                    #if os(iOS)
                    .withNavControls(router: router)
                    #endif
            }
            .tabItem { Label(Router.AppTab.accounting.title, systemImage: Router.AppTab.accounting.icon) }
            .tag(Router.AppTab.accounting)
        }
        .tint(.barnGreen)
    }
    #endif

    private var sidebarDetailView: some View {
        tabStack(for: router.selectedTab)
    }

    private var sidebarSelection: Binding<Router.AppTab?> {
        Binding(
            get: { router.selectedTab },
            set: { if let tab = $0 { router.selectedTab = tab } }
        )
    }

    /// The navigation stack for one tab, bound to that tab's path in the router.
    @ViewBuilder
    private func tabStack(for tab: Router.AppTab) -> some View {
        @Bindable var router = router
        switch tab {
        case .home:
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .withRouteDestinations()
                    #if os(iOS)
                    .withNavControls(router: router, onBrandHeader: true)
                    #endif
            }
        case .horses:
            NavigationStack(path: $router.horsesPath) {
                HorseListView()
                    .withRouteDestinations()
                    #if os(iOS)
                    .withNavControls(router: router)
                    #endif
            }
        case .clients:
            NavigationStack(path: $router.clientsPath) {
                ClientListView()
                    .withRouteDestinations()
                    #if os(iOS)
                    .withNavControls(router: router)
                    #endif
            }
        case .schedule:
            NavigationStack(path: $router.schedulePath) {
                BarnDashboardView()
                    .withRouteDestinations()
                    #if os(iOS)
                    .withNavControls(router: router)
                    #endif
            }
        case .accounting:
            NavigationStack(path: $router.accountingPath) {
                AccountingDashboardView()
                    .withRouteDestinations()
                    #if os(iOS)
                    .withNavControls(router: router)
                    #endif
            }
        }
    }
}

private extension View {
    #if os(iOS)
    /// Sync status and the Settings button for a tab's root screen.
    ///
    /// Must be applied inside the tab's `NavigationStack` (to the root view), or the
    /// navigation bar never picks the items up. `onBrandHeader` draws them white for
    /// Home before iOS 26, where the bar is transparent over the green header. From
    /// iOS 26 the items sit in a Liquid Glass capsule that turns light in light mode,
    /// where white all but vanishes, so they keep the system colors like every other
    /// screen.
    func withNavControls(router: Router, onBrandHeader: Bool = false) -> some View {
        let whiteOnHeader: Bool
        if #available(iOS 26.0, *) {
            whiteOnHeader = false
        } else {
            whiteOnHeader = onBrandHeader
        }
        // The sync badge is informational, so it's the first thing to fold into the
        // overflow menu on a narrow bar; the Settings button stays visible.
        return prioritizedToolbarItem(.low, placement: .topBarTrailing) {
            SyncIndicatorView(onBrandHeader: whiteOnHeader)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    router.navigate(to: HomeRoute.settings)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .foregroundStyle(whiteOnHeader ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                }
            }
        }
    }
    #endif
}
