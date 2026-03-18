import SwiftUI

struct SettingsView: View {
    @Environment(AppearanceManager.self) private var appearanceManager
    @Environment(StoreService.self) private var storeService
    @Environment(Router.self) private var router

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
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
                            Text("BarnIO Pro")
                            ProBadgeView()
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

            Section {
                externalLink("Privacy Policy", url: .privacyPolicy)
                externalLink("Terms of Use", url: .termsOfUse)
            }
        }
        .navigationTitle("Settings")
    }

    private func externalLink(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
