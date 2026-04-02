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
    @AppStorage("net.shadowpuppet.BarnBook.balancePeriod") private var balancePeriodRaw: Int = BalancePeriod.thisMonth.rawValue

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
        @Bindable var manager = appearanceManager
        List {
            Section("Appearance") {
                Picker("Theme", selection: $manager.mode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Home Screen") {
                Picker("Accounting Balance", selection: $balancePeriodRaw) {
                    ForEach(BalancePeriod.allCases) { period in
                        Text(period.displayName).tag(period.rawValue)
                    }
                }
            }

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
                    #if os(iOS)
                    Button {
                        router.navigate(to: SubscriptionRoute.paywall)
                    } label: {
                        HStack {
                            Text("Upgrade to Pro")
                            Spacer()
                            ProBadgeView()
                        }
                    }
                    #else
                    HStack {
                        Text("Upgrade to Pro on iPhone or iPad")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProBadgeView()
                    }
                    #endif
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

            Section("Data") {
                NavigationLink(value: HomeRoute.dataManagement) {
                    settingsRow("Import / Export", icon: "arrow.up.arrow.down")
                }
            }

            Section("Feedback") {
                #if os(iOS)
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
                #else
                if let url = URL(string: "mailto:\(Self.feedbackEmail)?subject=BarnHub%20Feedback") {
                    Link(destination: url) {
                        settingsRow("Send Feedback", icon: "envelope")
                    }
                }
                #endif
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
        .toast(isPresented: $showCodeRedeemedToast, message: "Pro unlocked!")
        .toast(isPresented: $showInvalidCodeToast, message: "Invalid code", isError: true)
    }

    private func settingsRow(_ title: String, icon: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func externalLink(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            settingsRow(title, icon: "arrow.up.right")
        }
    }
}
