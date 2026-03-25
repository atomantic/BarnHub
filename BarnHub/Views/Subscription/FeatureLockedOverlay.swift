import SwiftUI

struct FeatureLockedOverlay: ViewModifier {
    @Environment(StoreService.self) private var storeService
    @Environment(Router.self) private var router

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)

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
    }
}

extension View {
    func featureLockedOverlay() -> some View {
        modifier(FeatureLockedOverlay())
    }
}
