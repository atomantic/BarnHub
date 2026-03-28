import XCTest
@testable import BarnHub

final class FeatureGateTests: XCTestCase {
    func testFreeUserCannotAccessClients() {
        XCTAssertFalse(FeatureGate.canAccessClients(false))
    }

    func testProUserCanAccessClients() {
        XCTAssertTrue(FeatureGate.canAccessClients(true))
    }

    func testFreeUserCannotLinkClient() {
        XCTAssertFalse(FeatureGate.canLinkClientToTransaction(false))
    }

    func testProUserCanLinkClient() {
        XCTAssertTrue(FeatureGate.canLinkClientToTransaction(true))
    }

    func testFreeUserCannotAccessFullReports() {
        XCTAssertFalse(FeatureGate.canAccessFullReports(false))
    }

    func testProUserCanAccessFullReports() {
        XCTAssertTrue(FeatureGate.canAccessFullReports(true))
    }

    func testFreeUserCannotGenerateContracts() {
        XCTAssertFalse(FeatureGate.canGenerateContracts(false))
    }

    func testProUserCanGenerateContracts() {
        XCTAssertTrue(FeatureGate.canGenerateContracts(true))
    }

    func testFreeUserCannotStoreDocuments() {
        XCTAssertFalse(FeatureGate.canStoreDocuments(false))
    }

    func testProUserCanStoreDocuments() {
        XCTAssertTrue(FeatureGate.canStoreDocuments(true))
    }

    /// Verifies every gate function follows the isPro -> gate pattern
    func test_allGates_followIsProPattern() {
        let gates: [(Bool) -> Bool] = [
            FeatureGate.canAccessClients,
            FeatureGate.canLinkClientToTransaction,
            FeatureGate.canAccessFullReports,
            FeatureGate.canGenerateContracts,
            FeatureGate.canStoreDocuments,
        ]
        for gate in gates {
            XCTAssertTrue(gate(true), "Pro user should pass gate")
            XCTAssertFalse(gate(false), "Free user should not pass gate")
        }
    }
}
