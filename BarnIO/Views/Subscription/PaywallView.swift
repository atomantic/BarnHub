import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(StoreService.self) private var storeService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                featureComparison
                planCards
                purchaseButton
                restoreButton
                legalLinks
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("BarnIO Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toast(isPresented: $showToast, message: toastMessage, isError: toastIsError)
        .task {
            if storeService.products.isEmpty {
                await storeService.loadProducts()
            }
            selectedProduct = storeService.annualProduct ?? storeService.monthlyProduct
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.barnGreen)

            Text("Upgrade to Pro")
                .font(.title.weight(.bold))

            Text("Unlock the full power of BarnIO for your barn business.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    private var featureComparison: some View {
        VStack(spacing: 0) {
            comparisonHeader
            Divider()
            comparisonRow("Unlimited Horses", free: true, pro: true)
            comparisonRow("Vet & Farrier Records", free: true, pro: true)
            comparisonRow("Reminders & Supplies", free: true, pro: true)
            comparisonRow("Basic Accounting", free: true, pro: true)
            comparisonRow("Client Management", free: false, pro: true)
            comparisonRow("Client Billing", free: false, pro: true)
            comparisonRow("Full Reports", free: false, pro: true)
            comparisonRow("Data Export", free: false, pro: true)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
    }

    private var comparisonHeader: some View {
        HStack {
            Text("Feature")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Free")
                .font(.caption.weight(.semibold))
                .frame(width: 50)
            Text("Pro")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.barnGreen)
                .frame(width: 50)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private func comparisonRow(_ feature: String, free: Bool, pro: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(feature)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                checkOrX(free)
                    .frame(width: 50)
                checkOrX(pro)
                    .frame(width: 50)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()
        }
    }

    private func checkOrX(_ available: Bool) -> some View {
        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
            .foregroundStyle(available ? .barnGreen : .secondary.opacity(0.4))
            .font(.subheadline)
    }

    private var productsLoaded: Bool {
        !storeService.products.isEmpty
    }

    private var planCards: some View {
        VStack(spacing: 12) {
            if productsLoaded {
                if let monthly = storeService.monthlyProduct {
                    planCard(
                        product: monthly,
                        title: "Monthly",
                        subtitle: monthly.displayPrice + "/month"
                    )
                }
                if let annual = storeService.annualProduct {
                    planCard(
                        product: annual,
                        title: "Annual",
                        subtitle: annual.displayPrice + "/year",
                        badge: "7-day free trial"
                    )
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading plans...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }

    private func planCard(product: Product, title: String, subtitle: String, badge: String? = nil) -> some View {
        let isSelected = selectedProduct?.id == product.id
        return Button { selectedProduct = product } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange))
                        }
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .barnGreen : .secondary)
                    .font(.title3)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.barnGreen : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var canPurchase: Bool {
        selectedProduct != nil && !storeService.purchaseInProgress
    }

    private var purchaseButton: some View {
        Button {
            Task { await handlePurchase() }
        } label: {
            Group {
                if storeService.purchaseInProgress {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Subscribe Now")
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canPurchase ? Color.barnGreen : Color.barnGreen.opacity(0.4))
            )
        }
        .disabled(!canPurchase)
    }

    private var restoreButton: some View {
        Button {
            Task { await handleRestore() }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundStyle(.barnGreen)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("Terms of Use", destination: URL(string: "https://barniohq.com/terms")!)
            Link("Privacy Policy", destination: URL(string: "https://barniohq.com/privacy")!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @MainActor
    private func handlePurchase() async {
        guard let product = selectedProduct else { return }
        let success = await storeService.purchase(product)
        if success {
            await showToastAndDismiss("Welcome to BarnIO Pro!")
        }
    }

    @MainActor
    private func handleRestore() async {
        let restored = await storeService.restorePurchases()
        if restored {
            await showToastAndDismiss("Pro restored!")
        } else {
            toastMessage = "No active subscription found"
            toastIsError = true
            showToast = true
        }
    }

    @MainActor
    private func showToastAndDismiss(_ message: String) async {
        toastMessage = message
        toastIsError = false
        showToast = true
        try? await Task.sleep(for: .seconds(1))
        dismiss()
    }
}
