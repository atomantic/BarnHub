import Foundation
import StoreKit

typealias SKTransaction = StoreKit.Transaction

@Observable
final class StoreService {
    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var purchaseInProgress = false

    private var updateTask: Task<Void, Never>?

    static let monthlyID = "net.shadowpuppet.BarnBook.pro.monthly"
    static let annualID = "net.shadowpuppet.BarnBook.pro.annual"
    private static let productIDs: Set<String> = [monthlyID, annualID]

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var annualProduct: Product? { products.first { $0.id == Self.annualID } }

    init() {
        updateTask = Task { [weak self] in
            await self?.listenForUpdates()
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Self.productIDs)
            products = fetched.sorted { $0.price < $1.price }
            BarnIOLogger.success("Loaded \(fetched.count) products")
        } catch {
            BarnIOLogger.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    @MainActor
    func purchase(_ product: Product) async -> Bool {
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let txn = try checkVerified(verification)
                await txn.finish()
                await refreshEntitlements()
                BarnIOLogger.success("Purchase completed productID=\(product.id)")
                return true
            case .userCancelled:
                BarnIOLogger.info("Purchase cancelled by user")
                return false
            case .pending:
                BarnIOLogger.info("Purchase pending approval")
                return false
            @unknown default:
                return false
            }
        } catch {
            BarnIOLogger.error("Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            BarnIOLogger.success("Restore completed isPro=\(isPro)")
            return isPro
        } catch {
            BarnIOLogger.error("Restore failed: \(error.localizedDescription)")
            return false
        }
    }

    func refreshEntitlements() async {
        var foundPro = false
        for await result in SKTransaction.currentEntitlements {
            guard let txn = try? checkVerified(result) else { continue }
            if Self.productIDs.contains(txn.productID) {
                foundPro = true
                break
            }
        }
        await MainActor.run {
            if isPro != foundPro { isPro = foundPro }
        }
    }

    private func listenForUpdates() async {
        for await result in SKTransaction.updates {
            guard let txn = try? checkVerified(result) else { continue }
            await txn.finish()
            await refreshEntitlements()
            BarnIOLogger.info("Transaction update productID=\(txn.productID)")
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }
}
