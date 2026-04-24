import XCTest
@testable import BarnHub

final class StoreServiceTests: XCTestCase {

    // MARK: - Initial state

    func test_storeService_initialState_productsIsEmpty() {
        let service = StoreService()
        // Products are loaded asynchronously from App Store; in test context they won't load
        XCTAssertEqual(service.products.count, 0)
    }

    func test_storeService_productIDs_areKnown() {
        XCTAssertEqual(StoreService.monthlyID, "net.shadowpuppet.BarnBook.pro.monthly")
        XCTAssertEqual(StoreService.annualID, "net.shadowpuppet.BarnBook.pro.annual")
    }

    func test_storeService_lifetimeID_isKnown() {
        XCTAssertEqual(StoreService.lifetimeID, "net.shadowpuppet.BarnBook.pro.lifetime")
    }

    func test_storeService_initialState_isNotPro() {
        let service = StoreService()
        XCTAssertFalse(service.isPro)
        XCTAssertFalse(service.hasLifetime)
    }
}
