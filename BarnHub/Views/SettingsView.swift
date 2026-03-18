import MessageUI
import SwiftUI

struct SettingsView: View {
    @Environment(AppearanceManager.self) private var appearanceManager
    @Environment(StoreService.self) private var storeService
    @Environment(Router.self) private var router
    @State private var showingMailComposer = false
    @State private var showRedeemCodeSheet = false
    @State private var showManageSubscription = false

    private static let feedbackEmail = "atomantic@gmail.com"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private var feedbackBody: String {
        let device = UIDevice.current
        return """


        ---
        App: BarnHub v\(appVersion) (\(buildNumber))
        Device: \(device.model), iOS \(device.systemVersion)
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

            Section("Subscription") {
                if storeService.isPro {
                    HStack {
                        Text("Plan")
                        Spacer()
                        HStack(spacing: 4) {
                            Text("BarnHub Pro")
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

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(buildNumber)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Feedback") {
                if MFMailComposeViewController.canSendMail() {
                    Button {
                        showingMailComposer = true
                    } label: {
                        settingsRow("Send Feedback", icon: "envelope")
                    }
                } else {
                    Link(destination: URL(string: "mailto:\(Self.feedbackEmail)?subject=BarnHub%20Feedback")!) {
                        settingsRow("Send Feedback", icon: "envelope")
                    }
                }
            }

            Section {
                externalLink("Privacy Policy", url: .privacyPolicy)
                externalLink("Terms of Use", url: .termsOfUse)
            }
        }
        .navigationTitle("Settings")
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
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
