import XCTest
import SwiftData
@testable import BarnHub

/// Pro screens are locked where they're built (`Route.destination` via
/// `ProGated`), so these walk every route rather than the entry points.
final class FeatureGateTests: XCTestCase {
    private var container: ModelContainer!
    private var id: PersistentIdentifier!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: BarnHubSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let client = Client(firstName: "Anna")
        context.insert(client)
        try context.save()
        id = client.persistentModelID
    }

    override func tearDown() {
        container = nil
        id = nil
        super.tearDown()
    }

    /// The Pro-only screens, spelled out so a route can't lose its gate unnoticed.
    private func expectedFeature(_ route: any Hashable) -> ProFeature? {
        switch route {
        case let r as HomeRoute:
            return r == .clients ? .clients : nil
        case let r as HorseRoute:
            if case .documents = r { return .documents }
            return nil
        case let r as ClientRoute:
            switch r {
            case .invoiceHistory: return .invoices
            case .documents: return .documents
            default: return .clients
            }
        default:
            return nil
        }
    }

    func test_requiredFeature_matchesEveryRoute() {
        for route in AllRoutes.all(id) {
            XCTAssertEqual(FeatureGate.requiredFeature(for: route), expectedFeature(route), "\(route)")
        }
    }

    func test_freeUser_isLockedOutOfEveryProRoute() {
        for route in AllRoutes.all(id) {
            let isProRoute = expectedFeature(route) != nil
            XCTAssertEqual(FeatureGate.canOpen(route, isPro: false), !isProRoute, "\(route)")
        }
    }

    func test_proUser_canOpenEveryRoute() {
        for route in AllRoutes.all(id) {
            XCTAssertTrue(FeatureGate.canOpen(route, isPro: true), "\(route)")
        }
    }

    func test_proRoutesNamedInAudit_areGated() {
        XCTAssertFalse(FeatureGate.canOpen(ClientRoute.documents(id), isPro: false))
        XCTAssertFalse(FeatureGate.canOpen(ClientRoute.invoiceHistory(id), isPro: false))
        XCTAssertFalse(FeatureGate.canOpen(ClientRoute.detail(id), isPro: false))
        XCTAssertFalse(FeatureGate.canOpen(HomeRoute.clients, isPro: false))
        XCTAssertFalse(FeatureGate.canOpen(HorseRoute.documents(id), isPro: false))
    }

    func test_freeScreens_stayOpenToFreeUsers() {
        XCTAssertTrue(FeatureGate.canOpen(HorseRoute.detail(id), isPro: false))
        XCTAssertTrue(FeatureGate.canOpen(HomeRoute.reports, isPro: false), "Reports gates its Pro sections itself")
        XCTAssertTrue(FeatureGate.canOpen(SubscriptionRoute.paywall, isPro: false))
        XCTAssertTrue(FeatureGate.canOpen(BarnRoute.lessonEdit(nil), isPro: false))
    }

    func test_unknownRouteType_needsNothing() {
        XCTAssertNil(FeatureGate.requiredFeature(for: 42))
        XCTAssertTrue(FeatureGate.canOpen(42, isPro: false))
    }

    func test_everyProFeature_isLockedForFreeAndOpenForPro() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(FeatureGate.isUnlocked(feature, isPro: false), "\(feature)")
            XCTAssertTrue(FeatureGate.isUnlocked(feature, isPro: true), "\(feature)")
        }
    }
}
