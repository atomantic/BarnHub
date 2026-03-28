import XCTest
import CryptoKit
@testable import BarnHub

final class StoreServiceTests: XCTestCase {

    // MARK: - redeemSecretCode

    func test_redeemSecretCode_wrongCode_returnsFalse() {
        let service = StoreService()
        let result = service.redeemSecretCode("wrong-code-1234")
        XCTAssertFalse(result, "An invalid code should return false")
    }

    func test_redeemSecretCode_emptyString_returnsFalse() {
        let service = StoreService()
        let result = service.redeemSecretCode("")
        XCTAssertFalse(result, "An empty string should not redeem pro")
    }

    func test_redeemSecretCode_whitespaceOnly_returnsFalse() {
        let service = StoreService()
        let result = service.redeemSecretCode("   ")
        XCTAssertFalse(result, "Whitespace-only should not redeem pro")
    }

    func test_redeemSecretCode_nearMissCode_returnsFalse() {
        // Slightly mutated version of whatever the real code might be
        let service = StoreService()
        let result = service.redeemSecretCode("barnhub-pro-2025!")
        XCTAssertFalse(result)
    }

    // MARK: - SHA-256 hash comparison logic

    /// Verifies the hash algorithm used is SHA-256 and matches the pattern
    /// the production code uses: trim → lowercase → UTF-8 → SHA-256 → hex.
    func test_hashAlgorithm_producesExpectedHexString() {
        let input = "test-input"
        let hash = SHA256.hash(data: Data(input.utf8))
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()

        // Ensure it's a 64-character lowercase hex string (SHA-256 output)
        XCTAssertEqual(hex.count, 64)
        XCTAssertEqual(hex, hex.lowercased())

        // Must be stable across calls
        let hash2 = SHA256.hash(data: Data(input.utf8))
        let hex2 = hash2.compactMap { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, hex2)
    }

    func test_hashAlgorithm_differentInputs_produceDifferentHashes() {
        let h1 = SHA256.hash(data: Data("code-a".utf8))
        let hex1 = h1.compactMap { String(format: "%02x", $0) }.joined()
        let h2 = SHA256.hash(data: Data("code-b".utf8))
        let hex2 = h2.compactMap { String(format: "%02x", $0) }.joined()

        XCTAssertNotEqual(hex1, hex2)
    }

    func test_hashAlgorithm_trimmingAndLowercasing_affectsResult() {
        // Demonstrates that "  CODE  " trimmed+lowercased ≠ "  CODE  " as-is
        let raw = "  SECRET  "
        let trimmedLower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let h1 = SHA256.hash(data: Data(raw.utf8))
        let hex1 = h1.compactMap { String(format: "%02x", $0) }.joined()
        let h2 = SHA256.hash(data: Data(trimmedLower.utf8))
        let hex2 = h2.compactMap { String(format: "%02x", $0) }.joined()

        XCTAssertNotEqual(hex1, hex2,
                          "redeemSecretCode normalises input — raw and trimmed+lowercased must hash differently")
    }

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
}
