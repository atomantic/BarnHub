import SwiftUI

struct HomeView: View {
    @Environment(Router.self) private var router

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                iconGrid
                    .padding(.top, -30)
            }
        }
        .background(Color.barnOffWhite)
        .ignoresSafeArea(edges: .top)
    }

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            Color.barnGreen
                .frame(height: 260)

            VStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                Text("BarnBook")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 50)

            SwooshShape()
                .fill(Color.barnOffWhite)
                .frame(height: 50)
        }
    }

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            FeatureTile(icon: "figure.equestrian.sports", title: "Horses", color: .barnBrown) {
                router.navigate(to: HomeRoute.horses)
            }
            FeatureTile(icon: "person.2.fill", title: "Clients", color: .barnBrown) {
                router.navigate(to: HomeRoute.clients)
            }
            FeatureTile(icon: "calendar", title: "Schedule", color: .barnBrown) {
                router.navigate(to: HomeRoute.schedule)
            }
            FeatureTile(icon: "shippingbox.fill", title: "Supplies", color: .barnBrown) {
                router.navigate(to: HomeRoute.supplies)
            }
            FeatureTile(icon: "dollarsign.circle.fill", title: "Accounting", color: .barnBrown) {
                router.navigate(to: HomeRoute.accounting)
            }
            FeatureTile(icon: "chart.bar.fill", title: "Reports", color: .barnBrown) {
                router.navigate(to: HomeRoute.reports)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

struct FeatureTile: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundStyle(color)
                }
                .aspectRatio(1, contentMode: .fit)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.barnBrown)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SwooshShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: -rect.height * 0.6)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
