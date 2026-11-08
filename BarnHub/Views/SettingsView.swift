#if os(iOS)
import MessageUI
#endif
import SwiftUI

struct SettingsView: View {
    @Environment(AppearanceManager.self) private var appearanceManager
    @Environment(StoreService.self) private var storeService
    @Environment(SyncMonitor.self) private var syncMonitor
    #if os(iOS)
    @Environment(Router.self) private var router
    #endif
    @State private var showingMailComposer = false
    #if os(iOS)
    @State private var showRedeemCodeSheet = false
    #endif
    @State private var showManageSubscription = false
    @State private var showWelcomeSheet = false
    @State private var showBugReport = false
    #if os(macOS)
    @State private var showPaywall = false
    /// The Settings window reopens on the tab used last, like other Mac apps.
    @AppStorage("net.shadowpuppet.BarnBook.settings.tab") private var settingsTab = "general"
    #endif

    @AppStorage("net.shadowpuppet.BarnBook.balancePeriod") private var balancePeriodRaw: Int = BalancePeriod.thisMonth.rawValue
    @AppStorage("net.shadowpuppet.BarnBook.appLocale") private var appLocaleID: String = ""
    @AppStorage("net.shadowpuppet.BarnBook.currencyCode") private var currencyCode: String = ""

    private var supportedCurrencies: [(code: String, name: String)] {[
        ("USD", "US Dollar ($)"),
        ("EUR", "Euro (€)"),
        ("GBP", "British Pound (£)"),
        ("CAD", "Canadian Dollar (C$)"),
        ("AUD", "Australian Dollar (A$)"),
        ("CHF", "Swiss Franc (CHF)"),
        ("SEK", "Swedish Krona (kr)"),
        ("NOK", "Norwegian Krone (kr)"),
        ("DKK", "Danish Krone (kr)"),
        ("BRL", "Brazilian Real (R$)"),
        ("MXN", "Mexican Peso (MX$)"),
        ("JPY", "Japanese Yen (¥)"),
        ("NZD", "New Zealand Dollar (NZ$)"),
        ("ZAR", "South African Rand (R)"),
        ("ILS", "Israeli Shekel (₪)"),
        ("AED", "UAE Dirham (د.إ)"),
    ]}

    private var supportedLocales: [(id: String, name: String)] {[
        ("",       appLocalized("System Default", comment: "Language picker option")),
        ("en",     "English"),
        ("de",     "Deutsch"),
        ("fr",     "Français"),
        ("nl",     "Nederlands"),
        ("sv",     "Svenska"),
        ("es-ES",  "Español (España)"),
        ("es-MX",  "Español (México)"),
        ("pt-BR",  "Português (Brasil)"),
        ("it",     "Italiano"),
    ]}

    private static let feedbackEmail = "support@barnhub.online"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private var feedbackBody: String {
        #if os(iOS)
        let device = UIDevice.current
        let deviceInfo = "\(device.model), iOS \(device.systemVersion)"
        #else
        let deviceInfo = "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #endif
        return """

        ---
        App: BarnHub v\(appVersion) (\(buildNumber))
        Device: \(deviceInfo)
        """
    }

    var body: some View {
        settingsContent
            .navigationTitle("Settings")
            .inlineNavTitle()
            .barnManageSubscriptionsSheet(isPresented: $showManageSubscription)
            #if os(iOS)
            .offerCodeRedemption(isPresented: $showRedeemCodeSheet) { result in
                switch result {
                case .success:
                    BarnHubLogger.success("Offer code redeemed")
                    Task { await storeService.refreshEntitlements() }
                case .failure(let error):
                    BarnHubLogger.error("Offer code redemption failed: \(error.localizedDescription)")
                @unknown default:
                    break
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                MailComposer(
                    recipient: Self.feedbackEmail,
                    subject: "BarnHub Feedback",
                    body: feedbackBody,
                    onDismiss: { showingMailComposer = false }
                )
                .ignoresSafeArea()
            }
            #endif
            .sheet(isPresented: $showWelcomeSheet) {
                FirstLaunchSheet()
            }
            .sheet(isPresented: $showBugReport) {
                BugReportView()
            }
            #if os(macOS)
            .sheet(isPresented: $showPaywall) {
                NavigationStack {
                    PaywallView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showPaywall = false }
                            }
                        }
                }
                .frame(minWidth: 520, minHeight: 640)
            }
            #endif
    }

    // MARK: - Layout

    @ViewBuilder
    private var settingsContent: some View {
        #if os(iOS)
        iOSSettingsList
        #else
        macOSSettingsTabs
        #endif
    }

    // MARK: - iOS: List Layout

    #if os(iOS)
    private var iOSSettingsList: some View {
        List {
            appearanceSection
            homeScreenSection

            Section("Subscription") {
                if storeService.isPro {
                    HStack {
                        Text("Plan")
                        Spacer()
                        HStack(spacing: 4) {
                            Text(storeService.hasLifetime ? "Lifetime" : "BarnHub")
                            ProBadgeView()
                        }
                    }
                    Button {
                        showManageSubscription = true
                    } label: {
                        settingsRow("Manage Subscription", icon: "creditcard")
                    }
                } else {
                    Button {
                        router.navigate(to: SubscriptionRoute.paywall)
                    } label: {
                        HStack {
                            Text("Upgrade to Pro")
                            Spacer()
                            ProBadgeView()
                        }
                    }
                    Button {
                        showRedeemCodeSheet = true
                    } label: {
                        settingsRow("Redeem Code", icon: "gift")
                    }
                }
            }

            iCloudSyncSection
            dataSection

            Section("Feedback") {
                if MFMailComposeViewController.canSendMail() {
                    Button {
                        showingMailComposer = true
                    } label: {
                        settingsRow("Send Feedback", icon: "envelope")
                    }
                } else {
                    if let url = URL(string: "mailto:\(Self.feedbackEmail)?subject=BarnHub%20Feedback") {
                        Link(destination: url) {
                            settingsRow("Send Feedback", icon: "envelope")
                        }
                    }
                }
                Button {
                    showBugReport = true
                } label: {
                    settingsRow("Report a Bug", icon: "ladybug")
                }
                Button {
                    showWelcomeSheet = true
                } label: {
                    settingsRow("Show Welcome Screen", icon: "sparkles")
                }
            }

            Section("Legal") {
                externalLink("Privacy Policy", url: .privacyPolicy)
                externalLink("Terms of Use", url: .termsOfUse)
            }

            Section {
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
    }
    #endif

    // MARK: - macOS: Settings window
    // A tabbed preferences window, opened from BarnHub ▸ Settings… (⌘,) and the
    // sidebar's gear, instead of a page pushed into the main window.

    #if os(macOS)
    private var macOSSettingsTabs: some View {
        TabView(selection: $settingsTab) {
            Form {
                appearanceSection
                homeScreenSection
                iCloudSyncSection
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }
            .tag("general")

            Form { subscriptionSection }
                .formStyle(.grouped)
                .tabItem { Label("Subscription", systemImage: "creditcard") }
                .tag("subscription")

            DataManagementView()
                .tabItem { Label("Data", systemImage: "arrow.up.arrow.down") }
                .tag("data")

            Form {
                feedbackSection
                Section("Legal") {
                    externalLink("Privacy Policy", url: .privacyPolicy)
                    externalLink("Terms of Use", url: .termsOfUse)
                }
                Section {
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Feedback", systemImage: "envelope") }
            .tag("feedback")
        }
        .frame(width: 520, height: 460)
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            if storeService.isPro {
                HStack {
                    Text("Plan")
                    Spacer()
                    HStack(spacing: 4) {
                        Text(storeService.hasLifetime ? "Lifetime" : "BarnHub")
                        ProBadgeView()
                    }
                }
                Button {
                    showManageSubscription = true
                } label: {
                    settingsRow("Manage Subscription", icon: "creditcard")
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Text("Upgrade to Pro")
                        Spacer()
                        ProBadgeView()
                    }
                }
                if let url = URL(string: "macappstore://apps.apple.com/redeem?ctx=offercodes") {
                    Link(destination: url) {
                        settingsRow("Redeem Code", icon: "gift")
                    }
                }
            }
        }
    }

    private var feedbackSection: some View {
        Section("Feedback") {
            if let url = URL(string: "mailto:\(Self.feedbackEmail)?subject=BarnHub%20Feedback") {
                Link(destination: url) {
                    settingsRow("Send Feedback", icon: "envelope")
                }
            }
            Button {
                showBugReport = true
            } label: {
                settingsRow("Report a Bug", icon: "ladybug")
            }
            Button {
                showWelcomeSheet = true
            } label: {
                settingsRow("Show Welcome Screen", icon: "sparkles")
            }
        }
    }
    #endif

    // MARK: - Shared Sections

    private var appearanceSection: some View {
        @Bindable var manager = appearanceManager
        return Section("Appearance") {
            Picker("Theme", selection: $manager.mode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Picker("Language", selection: $appLocaleID) {
                ForEach(supportedLocales, id: \.id) { locale in
                    Text(locale.name).tag(locale.id)
                }
            }
            .onChange(of: appLocaleID) { _, newValue in
                Bundle.resetAppBundleCache()
                if newValue.isEmpty {
                    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                } else {
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                }
            }
            Picker("Currency", selection: $currencyCode) {
                Text("US Dollar ($)").tag("")
                ForEach(supportedCurrencies.filter { $0.code != "USD" }, id: \.code) { currency in
                    Text(currency.name).tag(currency.code)
                }
            }
        }
    }

    private var homeScreenSection: some View {
        Section("Home Screen") {
            Picker("Accounting Balance", selection: $balancePeriodRaw) {
                ForEach(BalancePeriod.allCases) { period in
                    Text(period.displayName).tag(period.rawValue)
                }
            }
        }
    }

    private var iCloudSyncSection: some View {
        Section("iCloud Sync") {
            HStack(spacing: 10) {
                Image(systemName: syncMonitor.status.icon)
                    .foregroundStyle(syncMonitor.status.tint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(syncMonitor.status.label)
                        .font(.subheadline)
                    if let lastSync = syncMonitor.lastSuccessfulSync {
                        Text("Last synced \(lastSync.relativeDateString)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            NavigationLink(value: HomeRoute.dataManagement) {
                settingsRow("Import / Export", icon: "arrow.up.arrow.down")
            }
        }
    }

    // MARK: - Helpers

    private func settingsRow(_ title: LocalizedStringKey, icon: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func externalLink(_ title: LocalizedStringKey, url: URL) -> some View {
        Link(destination: url) {
            settingsRow(title, icon: "arrow.up.right")
        }
    }
}
