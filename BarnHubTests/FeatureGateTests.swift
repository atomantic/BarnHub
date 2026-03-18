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

    func testFreeUserCannotExportData() {
        XCTAssertFalse(FeatureGate.canExportData(false))
    }

    func testProUserCanExportData() {
        XCTAssertTrue(FeatureGate.canExportData(true))
    }
}
