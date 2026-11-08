import SwiftUI

// MARK: - Feature Tile (iOS + macOS quick nav)

struct FeatureTile: View {
    let icon: String
    let title: LocalizedStringKey
    let color: Color
    var badge: String? = nil
    var badgeColor: Color? = nil
    var badgeDetail: String? = nil
    var tag: String? = nil
    let action: () -> Void

    #if os(macOS)
    private var tileSpacing: CGFloat { 6 }
    private var tileRadius: CGFloat { 10 }
    private var tileIconFont: Font { .body }
    #else
    private var tileSpacing: CGFloat { 10 }
    private var tileRadius: CGFloat { 16 }
    private var tileIconFont: Font { .title }
    #endif

    var body: some View {
        Button(action: action) {
            VStack(spacing: tileSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: tileRadius)
                        .fill(.barnCardBackground)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(tileIconFont)
                            .foregroundStyle(color)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(badgeColor ?? .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        if let badgeDetail {
                            Text(badgeDetail)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                #if os(macOS)
                .frame(height: 72)
                #else
                .aspectRatio(1, contentMode: .fit)
                #endif

                Text(title)
                    .font(.caption.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.barnBrown)
            }
        }
        .buttonStyle(.plain)
        .modifier(OptionalAccessibilityID(tag))
    }
}

private struct OptionalAccessibilityID: ViewModifier {
    let id: String?
    init(_ id: String?) { self.id = id }
    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}
