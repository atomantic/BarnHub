import Foundation

enum FeatureGate {
    static func canAccessClients(_ isPro: Bool) -> Bool { isPro }
    static func canLinkClientToTransaction(_ isPro: Bool) -> Bool { isPro }
    static func canAccessFullReports(_ isPro: Bool) -> Bool { isPro }
    static func canGenerateInvoices(_ isPro: Bool) -> Bool { isPro }
    static func canGenerateContracts(_ isPro: Bool) -> Bool { isPro }
    static func canStoreDocuments(_ isPro: Bool) -> Bool { isPro }

    static func isUnlocked(_ feature: ProFeature, isPro: Bool) -> Bool {
        switch feature {
        case .clients: canAccessClients(isPro)
        case .invoices: canGenerateInvoices(isPro)
        case .documents: canStoreDocuments(isPro)
        }
    }

    /// The Pro feature a route's screen needs, or nil when anyone can open it.
    static func requiredFeature(for route: any Hashable) -> ProFeature? {
        switch route {
        case let r as HomeRoute: r.requiredProFeature
        case let r as HorseRoute: r.requiredProFeature
        case let r as ClientRoute: r.requiredProFeature
        case let r as AccountingRoute: r.requiredProFeature
        case let r as BarnRoute: r.requiredProFeature
        case let r as SubscriptionRoute: r.requiredProFeature
        default: nil
        }
    }

    /// Whether `route` shows its screen rather than the upgrade view. Checked at
    /// the destination, so deep links, notifications and the sidebar can't reach
    /// a Pro screen that the entry points hide.
    static func canOpen(_ route: any Hashable, isPro: Bool) -> Bool {
        guard let feature = requiredFeature(for: route) else { return true }
        return isUnlocked(feature, isPro: isPro)
    }
}

/// A part of the app that needs BarnHub Pro.
enum ProFeature: CaseIterable {
    case clients
    case invoices
    case documents
}
