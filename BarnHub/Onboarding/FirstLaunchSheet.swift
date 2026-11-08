import SwiftUI
import SwiftData
import StoreKit

/// Multi-page introductory sheet shown the first time the app is launched.
/// - `welcome`: brand privacy promise (no accounts, iCloud sync, export anytime)
/// - `notification`: primes the iOS notification permission so it never fires cold
/// - `firstHorse`: captures the user's first horse (honest value-delivery)
/// - `hasClients`: routes to Pro offer if the user manages clients
/// - `proOffer`: compact paywall with 7-day trial on subscription plans + lifetime
/// `interactiveDismissDisabled` blocks swipe-to-dismiss so `hasCompletedFirstLaunch`
/// is only set via an explicit button press.
struct FirstLaunchSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationService.self) private var notificationService
    @Environment(StoreService.self) private var storeService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("net.shadowpuppet.BarnBook.hasCompletedFirstLaunch") private var hasCompletedFirstLaunch = false

    private enum Page { case welcome, notification, firstHorse, hasClients, proOffer }
    @State private var page: Page = .welcome

    @State private var horseName = ""
    @State private var horseBreed = ""
    @State private var selectedProduct: Product?
    @State private var toast = ToastState()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    switch page {
                    case .welcome: welcomePage
                    case .notification: notificationPage
                    case .firstHorse: firstHorsePage
                    case .hasClients: hasClientsPage
                    case .proOffer: proOfferPage
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 16)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            footer
        }
        .background(Color.systemBackground)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 620)
        #endif
        .interactiveDismissDisabled(true)
        .toast(toast)
        .task {
            if storeService.products.isEmpty {
                await storeService.loadProducts()
            }
            selectedProduct = storeService.annualProduct ?? storeService.lifetimeProduct ?? storeService.monthlyProduct
        }
    }

    @ViewBuilder
    private var welcomePage: some View {
        Image(systemName: "house.fill")
            .font(.system(size: 56))
            .foregroundStyle(.barnGreen)
            .padding(.top, 16)
            .accessibilityHidden(true)

        Text(appLocalized("Welcome to BarnHub"))
            .font(.title).fontWeight(.bold)
            .multilineTextAlignment(.center)

        Text(appLocalized("Your barn, in your pocket — and your iCloud."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        VStack(alignment: .leading, spacing: 16) {
            privacyBullet(
                icon: "lock.shield.fill",
                title: appLocalized("Private by design"),
                detail: appLocalized("No accounts, no servers, no telemetry. Your horse and client data is yours alone.")
            )
            privacyBullet(
                icon: "icloud.fill",
                title: appLocalized("Synced through your iCloud"),
                detail: appLocalized("Encrypted by Apple and shared only with your other Apple devices — your iPhone, iPad, and Mac stay in sync automatically.")
            )
            privacyBullet(
                icon: "square.and.arrow.up",
                title: appLocalized("Export anytime"),
                detail: appLocalized("Take your data with you. It never leaves your devices unless you explicitly share it.")
            )
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var notificationPage: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: 56))
            .foregroundStyle(.barnGreen)
            .padding(.top, 16)
            .accessibilityHidden(true)

        Text(appLocalized("Stay on top of the barn"))
            .font(.title).fontWeight(.bold)
            .multilineTextAlignment(.center)

        Text(appLocalized("BarnHub can quietly remind you about what's coming up."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        VStack(alignment: .leading, spacing: 16) {
            privacyBullet(
                icon: "stethoscope",
                title: appLocalized("Vet, farrier & dentist visits"),
                detail: appLocalized("Get a heads-up before each scheduled appointment so nothing slips.")
            )
            privacyBullet(
                icon: "checklist",
                title: appLocalized("Reminders & lessons"),
                detail: appLocalized("A small nudge for the day's chores, lessons, and overdue tasks.")
            )
            privacyBullet(
                icon: "lock.fill",
                title: appLocalized("Stays on your device"),
                detail: appLocalized("Reminders are scheduled by iOS itself. Nothing leaves your device.")
            )
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var firstHorsePage: some View {
        Image(systemName: "figure.equestrian.sports")
            .font(.system(size: 56))
            .foregroundStyle(.barnGreen)
            .padding(.top, 16)
            .accessibilityHidden(true)

        Text(appLocalized("Meet your first horse"))
            .font(.title).fontWeight(.bold)
            .multilineTextAlignment(.center)

        Text(appLocalized("Add one now so your barn isn't empty. You can add more — and edit this one — anytime."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appLocalized("Name"))
                    .font(.caption).foregroundStyle(.secondary)
                TextField(appLocalized("e.g. Starfire"), text: $horseName)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(appLocalized("Breed (optional)"))
                    .font(.caption).foregroundStyle(.secondary)
                TextField(appLocalized("e.g. Thoroughbred"), text: $horseBreed)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var hasClientsPage: some View {
        Image(systemName: "person.2.fill")
            .font(.system(size: 56))
            .foregroundStyle(.barnGreen)
            .padding(.top, 16)
            .accessibilityHidden(true)

        Text(appLocalized("Do you manage clients?"))
            .font(.title).fontWeight(.bold)
            .multilineTextAlignment(.center)

        Text(appLocalized("If you board horses for others, teach lessons, or invoice clients, BarnHub Pro unlocks the client tools."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        VStack(alignment: .leading, spacing: 16) {
            privacyBullet(
                icon: "person.crop.circle.badge.checkmark",
                title: appLocalized("Client profiles & horses"),
                detail: appLocalized("Link horses to clients, track contact info, and see everything in one place.")
            )
            privacyBullet(
                icon: "doc.text.fill",
                title: appLocalized("Contracts & invoices"),
                detail: appLocalized("Generate PDFs for boarding agreements and bill clients from your accounting.")
            )
            privacyBullet(
                icon: "chart.bar.fill",
                title: appLocalized("Full reports"),
                detail: appLocalized("Income by client, outstanding balances, and deeper accounting analytics.")
            )
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var proOfferPage: some View {
        Image(systemName: "star.circle.fill")
            .font(.system(size: 56))
            .foregroundStyle(.barnGreen)
            .padding(.top, 16)
            .accessibilityHidden(true)

        Text(appLocalized("Try BarnHub Pro free for 7 days"))
            .font(.title).fontWeight(.bold)
            .multilineTextAlignment(.center)

        VStack(spacing: 6) {
            Text(appLocalized("Full access to clients, contracts, invoices, and reports."))
            Text(appLocalized("Cancel anytime during the trial."))
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

        VStack(spacing: 10) {
            if storeService.products.isEmpty {
                if storeService.productsLoadFailed {
                    Text(appLocalized("Unable to load subscription plans"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(appLocalized("Try Again")) {
                        Task { await storeService.loadProducts() }
                    }
                    .foregroundStyle(.barnGreen)
                } else {
                    ProgressView().padding(.vertical, 16)
                }
            } else {
                if let monthly = storeService.monthlyProduct {
                    planCard(product: monthly, title: appLocalized("Monthly"),
                             subtitle: monthly.displayPrice + appLocalized("/month"),
                             badge: monthly.subscription?.introductoryOffer != nil ? appLocalized("7-day free trial") : nil)
                }
                if let annual = storeService.annualProduct {
                    planCard(product: annual, title: appLocalized("Annual"),
                             subtitle: annual.displayPrice + appLocalized("/year"),
                             badge: annual.subscription?.introductoryOffer != nil ? appLocalized("7-day free trial") : appLocalized("Best value"))
                }
                if let lifetime = storeService.lifetimeProduct {
                    planCard(product: lifetime, title: appLocalized("Lifetime"),
                             subtitle: lifetime.displayPrice + appLocalized(" once"),
                             badge: appLocalized("One-time purchase"))
                }
            }
        }
        .padding(.top, 8)

        Text(appLocalized("Auto-renews unless cancelled. Manage in App Store settings."))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    @ViewBuilder
    private func planCard(product: Product, title: String, subtitle: String, badge: String?) -> some View {
        let isSelected = selectedProduct?.id == product.id
        Button { selectedProduct = product } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange))
                        }
                    }
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .barnGreen : .secondary)
                    .font(.title3)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.barnGreen : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            Divider()

            switch page {
            case .welcome:
                primaryButton(appLocalized("Continue")) {
                    withAnimation(.easeInOut(duration: 0.25)) { page = .notification }
                }

            case .notification:
                VStack(spacing: 8) {
                    primaryButton(appLocalized("Turn on reminders")) {
                        Task {
                            await notificationService.requestAuthorization()
                            withAnimation(.easeInOut(duration: 0.25)) { page = .firstHorse }
                        }
                    }
                    Button(appLocalized("Not now")) {
                        withAnimation(.easeInOut(duration: 0.25)) { page = .firstHorse }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

            case .firstHorse:
                VStack(spacing: 8) {
                    primaryButton(appLocalized("Add Horse")) {
                        addHorseIfNamed()
                        withAnimation(.easeInOut(duration: 0.25)) { page = .hasClients }
                    }
                    .disabled(horseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button(appLocalized("Skip")) {
                        withAnimation(.easeInOut(duration: 0.25)) { page = .hasClients }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

            case .hasClients:
                VStack(spacing: 8) {
                    primaryButton(appLocalized("Yes, I manage clients")) {
                        if storeService.isPro {
                            complete()
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) { page = .proOffer }
                        }
                    }
                    Button(appLocalized("No, just my own horses")) {
                        complete()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

            case .proOffer:
                VStack(spacing: 8) {
                    primaryButton(purchaseLabel) {
                        Task { await handlePurchase() }
                    }
                    .disabled(selectedProduct == nil || storeService.purchaseInProgress)
                    Button(appLocalized("Maybe later")) {
                        complete()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    private var purchaseLabel: String {
        if storeService.purchaseInProgress { return appLocalized("Starting…") }
        guard let product = selectedProduct else { return appLocalized("Start 7-day Free Trial") }
        if product.id == StoreService.lifetimeID { return appLocalized("Buy Lifetime") }
        if product.subscription?.introductoryOffer != nil { return appLocalized("Start 7-day Free Trial") }
        return appLocalized("Subscribe")
    }

    @ViewBuilder
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if storeService.purchaseInProgress && page == .proOffer {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.barnGreen)
        .padding(.horizontal, page == .welcome ? 24 : 0)
    }

    private func addHorseIfNamed() {
        let trimmedName = horseName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let horse = Horse(
            name: trimmedName,
            breed: horseBreed.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(horse)
        BarnHubLogger.success("First horse added during onboarding")
    }

    @MainActor
    private func handlePurchase() async {
        guard let product = selectedProduct else { return }
        let success = await storeService.purchase(product)
        if success {
            toast.show(appLocalized("Welcome to BarnHub Pro!"))
            try? await Task.sleep(for: .seconds(1))
            complete()
        } else if !storeService.purchaseInProgress {
            toast.show(appLocalized("Purchase didn't complete"), isError: true)
        }
    }

    @ViewBuilder
    private func privacyBullet(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.barnGreen)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func complete() {
        hasCompletedFirstLaunch = true
        dismiss()
    }
}
