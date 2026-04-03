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
    @State private var showRedeemCodeSheet = false
    @State private var showManageSubscription = false
    @State private var showSecretCodeAlert = false
    @State private var secretCodeInput = ""
    @State private var showInvalidCodeToast = false
    @State private var showCodeRedeemedToast = false
    @State private var showRestartAlert = false
    @AppStorage("net.shadowpuppet.BarnBook.balancePeriod") private var balancePeriodRaw: Int = BalancePeriod.thisMonth.rawValue
    @AppStorage("net.shadowpuppet.BarnBook.appLocale") private var appLocaleID: String = ""

    private static let supportedLocales: [(id: String, name: String)] = [
        ("",       "System Default"),
        ("en",     "English"),
        ("de",     "Deutsch"),
        ("fr",     "Français"),
        ("nl",     "Nederlands"),
        ("sv",     "Svenska"),
        ("es-ES",  "Español (España)"),
        ("es-MX",  "Español (México)"),
        ("pt-BR",  "Português (Brasil)"),
        ("it",     "Italiano"),
    ]

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
            .barnOfferCodeRedemption(isPresented: $showRedeemCodeSheet) { result in
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
            #if os(iOS)
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
            .alert("Enter Secret Code", isPresented: $showSecretCodeAlert) {
                TextField("Code", text: $secretCodeInput)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                Button("Redeem") {
                    if storeService.redeemSecretCode(secretCodeInput) {
                        showCodeRedeemedToast = true
                    } else {
                        showInvalidCodeToast = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter the code you received to unlock BarnHub Pro.")
            }
            .toast(isPresented: $showCodeRedeemedToast, message: String(localized: "Pro unlocked!"))
            .toast(isPresented: $showInvalidCodeToast, message: String(localized: "Invalid code"), isError: true)
    }

    // MARK: - Layout

    @ViewBuilder
    private var settingsContent: some View {
        #if os(iOS)
        iOSSettingsList
        #else
        macOSColumnsSettings
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
                    if storeService.hasSecretPro {
                        Toggle("Basic Mode", isOn: Binding(
                            get: { storeService.isProOverrideDisabled },
                            set: { storeService.isProOverrideDisabled = $0 }
                        ))
                    } else {
                        Button {
                            showManageSubscription = true
                        } label: {
                            settingsRow("Manage Subscription", icon: "creditcard")
                        }
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
                    Button {
                        secretCodeInput = ""
                        showSecretCodeAlert = true
                    } label: {
                        settingsRow("Enter Secret Code", icon: "lock.open")
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
            }

            Section {
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

    // MARK: - macOS: Responsive Columns
    // >= 860pt -> 3 columns | >= 540pt -> 2 columns | < 540pt -> 1 column

    #if os(macOS)
    private var macOSColumnsSettings: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ScrollView {
                Group {
                    if w >= 860 {
                        HStack(alignment: .top, spacing: 16) {
                            col1.frame(maxWidth: .infinity)
                            col2.frame(maxWidth: .infinity)
                            col3.frame(maxWidth: .infinity)
                        }
                    } else if w >= 540 {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(spacing: 16) { col1; col3 }.frame(maxWidth: .infinity)
                            col2.frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 16) { col1; col2; col3 }
                    }
                }
                .padding()
            }
        }
    }

    private var col1: some View {
        Form {
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
                    if storeService.hasSecretPro {
                        Toggle("Basic Mode", isOn: Binding(
                            get: { storeService.isProOverrideDisabled },
                            set: { storeService.isProOverrideDisabled = $0 }
                        ))
                    } else {
                        Button {
                            showManageSubscription = true
                        } label: {
                            settingsRow("Manage Subscription", icon: "creditcard")
                        }
                    }
                } else {
                    HStack {
                        Text("Upgrade to Pro on iPhone or iPad")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProBadgeView()
                    }
                    Button {
                        showRedeemCodeSheet = true
                    } label: {
                        settingsRow("Redeem Code", icon: "gift")
                    }
                    Button {
                        secretCodeInput = ""
                        showSecretCodeAlert = true
                    } label: {
                        settingsRow("Enter Secret Code", icon: "lock.open")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var col2: some View {
        Form {
            iCloudSyncSection
            dataSection
            Section("Feedback") {
                if let url = URL(string: "mailto:\(Self.feedbackEmail)?subject=BarnHub%20Feedback") {
                    Link(destination: url) {
                        settingsRow("Send Feedback", icon: "envelope")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var col3: some View {
        Form {
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
                ForEach(Self.supportedLocales, id: \.id) { locale in
                    Text(locale.name).tag(locale.id)
                }
            }
            .onChange(of: appLocaleID) { _, newValue in
                if newValue.isEmpty {
                    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                } else {
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                }
                showRestartAlert = true
            }
            .alert("Restart Required", isPresented: $showRestartAlert) {
                Button("Restart Now") { exit(0) }
                Button("Later", role: .cancel) {}
            } message: {
                Text("Please restart BarnHub to apply the language change.")
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
                    if case .failed(let msg) = syncMonitor.status {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.red)
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
