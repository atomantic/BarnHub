import SwiftUI
import SwiftData
import UserNotifications

@main
struct BarnHubApp: App {
    @State private var router = Router()
    @State private var storeService = StoreService()
    @State private var appearanceManager = AppearanceManager()
    @State private var notificationService = NotificationService()
    @State private var syncMonitor = SyncMonitor()
    @AppStorage("net.shadowpuppet.BarnBook.appLocale") private var appLocaleID: String = ""

    private var appLocale: Locale {
        appLocaleID.isEmpty ? .current : Locale(identifier: appLocaleID)
    }

    #if os(macOS)
    @NSApplicationDelegateAdaptor(BarnHubMacAppDelegate.self) private var appDelegate
    #endif

    init() {
        // Before launch finishes, so a tap that cold-launches the app is delivered.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    /// `-SeedSampleData` (Debug builds only): an in-memory store filled with sample
    /// data. A release build must never trade the user's iCloud store for an
    /// in-memory one because of a launch argument.
    private static var isSeedModeRequested: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-SeedSampleData")
        #else
        false
        #endif
    }

    private var modelContainer: ModelContainer = {
        let isSeedMode = Self.isSeedModeRequested
        let config = isSeedMode
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(cloudKitDatabase: .automatic)
        StorageMode.current = isSeedMode ? .inMemorySeed : .cloudKit
        do {
            let container = try ModelContainer(
                for: BarnHubSchema.schema,
                migrationPlan: BarnHubMigrationPlan.self,
                configurations: config
            )
            #if DEBUG
            if isSeedMode {
                PreviewSampleData.populate(container: container)
            }
            #endif
            return container
        } catch {
            BarnHubLogger.error("ModelContainer init failed: \(error.localizedDescription) — falling back to in-memory store")
            do {
                let fallback = try ModelContainer(
                    for: BarnHubSchema.schema,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
                StorageMode.current = .inMemoryFallback
                return fallback
            } catch {
                BarnHubLogger.error("Fallback in-memory ModelContainer init also failed: \(error.localizedDescription)")
                fatalError("Unable to initialize SwiftData ModelContainer (both persistent and in-memory initializations failed).")
            }
        }
    }()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .preferredColorScheme(appearanceManager.colorScheme)
                .environment(\.locale, appLocale)
                .environment(router)
                .environment(storeService)
                .environment(appearanceManager)
                .environment(notificationService)
                .environment(syncMonitor)
                .task {
                    ShareTempFiles.purgeLeftoversAtLaunch()
                    // Refresh status only — never request cold. The actual permission
                    // request happens after the user opts in via FirstLaunchSheet.
                    await notificationService.refreshAuthorizationStatus()
                }
                #if os(macOS)
                .onAppear {
                    BarnHubMacAppDelegate.reopenWindow = nil
                }
                #endif
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #elseif targetEnvironment(macCatalyst)
        .defaultSize(width: 1024, height: 768)
        #endif
        .commands {
            SidebarCommands()

            CommandMenu("Go") {
                ForEach(Router.AppTab.allCases, id: \.self) { tab in
                    Button {
                        // Match iOS tab-bar semantics: switch preserves the stack;
                        // re-pressing the current tab's shortcut pops to root.
                        if router.selectedTab == tab {
                            router.popToRoot(tab: tab)
                        } else {
                            router.selectedTab = tab
                        }
                    } label: {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .keyboardShortcut(tab.keyboardShortcut, modifiers: .command)
                }
            }

            // File ▸ New… in place of New Window: BarnHub is a single-window app.
            CommandGroup(replacing: .newItem) {
                Button("New Horse") {
                    router.navigate(to: HorseRoute.edit(nil), tab: .horses)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Client") {
                    router.navigate(to: ClientRoute.edit(nil), tab: .clients)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!FeatureGate.canAccessClients(storeService.isPro))

                Button("New Transaction") {
                    router.navigate(to: AccountingRoute.edit(nil), tab: .accounting)
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }

            #if os(macOS)
            CommandGroup(replacing: .appTermination) {
                Button("Quit BarnHub") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
            #endif
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(storeService)
                .environment(appearanceManager)
                .environment(syncMonitor)
                .modelContainer(modelContainer)
        }
        #endif
    }
}
