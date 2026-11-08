import SwiftUI

struct FeatureLockedOverlay: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)

                    ProLockedMessage()
                }
            }
    }
}

extension View {
    func featureLockedOverlay() -> some View {
        modifier(FeatureLockedOverlay())
    }
}

/// The lock icon, pitch and View Plans button shown in place of a Pro feature.
struct ProLockedMessage: View {
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(.barnGreen)
                .accessibilityHidden(true)

            Text("Upgrade to Pro")
                .font(.headline)

            Text("Unlock full reports, client management, and more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                router.navigate(to: SubscriptionRoute.paywall)
            } label: {
                Text("View Plans")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.barnGreen))
            }
        }
        .padding(24)
    }
}

/// Shows `content` only when the user has `feature` (or nothing is required),
/// and the upgrade view otherwise. Route destinations wrap their screens in it,
/// so a Pro screen stays locked however it was reached.
struct ProGated<Content: View>: View {
    let feature: ProFeature?
    @ViewBuilder let content: Content
    @Environment(StoreService.self) private var storeService

    var body: some View {
        if let feature, !FeatureGate.isUnlocked(feature, isPro: storeService.isPro) {
            switch feature {
            case .clients:
                ClientsUpgradeView()
            case .invoices, .documents:
                ProLockedMessage()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            content
        }
    }
}
