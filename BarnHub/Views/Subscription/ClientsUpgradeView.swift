import SwiftUI

struct ClientsUpgradeView: View {
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(.barnGreen)

            Text("Client Management")
                .font(.title2.weight(.bold))

            Text("Track clients, assign horses, manage billing, and view payment history — all in one place.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "person.crop.circle.badge.plus", text: "Add & manage clients")
                featureRow(icon: "figure.equestrian.sports", text: "Assign horses to clients")
                featureRow(icon: "dollarsign.arrow.circlepath", text: "Track client payments")
                featureRow(icon: "phone.fill", text: "Emergency contacts on file")
            }
            .padding(.horizontal, 40)

            Button {
                router.navigate(to: SubscriptionRoute.paywall)
            } label: {
                HStack {
                    Text("Upgrade to BarnHub Pro")
                        .fontWeight(.semibold)
                    ProBadgeView()
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.barnGreen)
                )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .navigationTitle("Clients")
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.barnGreen)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
