import Foundation

enum FeatureGate {
    static func canAccessClients(_ isPro: Bool) -> Bool { isPro }
    static func canLinkClientToTransaction(_ isPro: Bool) -> Bool { isPro }
    static func canAccessFullReports(_ isPro: Bool) -> Bool { isPro }
}
