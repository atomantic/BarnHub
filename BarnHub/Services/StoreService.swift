import Foundation
import StoreKit

typealias SKTransaction = StoreKit.Transaction

@Observable
final class StoreService {
    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var purchaseInProgress = false
    private(set) var productsLoadFailed = false

    private var updateTask: Task<Void, Never>?
    private var setupTask: Task<Void, Never>?

    static let monthlyID = "net.shadowpuppet.BarnBook.pro.monthly"
    static let annualID = "net.shadowpuppet.BarnBook.pro.annual"
    static let lifetimeID = "net.shadowpuppet.BarnBook.pro.lifetime"
    private static let subscriptionIDs: Set<String> = [monthlyID, annualID]
    private static let productIDs: Set<String> = [monthlyID, annualID, lifetimeID]

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var annualProduct: Product? { products.first { $0.id == Self.annualID } }
    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }
    private(set) var hasLifetime = false

    #if DEBUG
    private let forceProMode = ProcessInfo.processInfo.arguments.contains("-ForceProMode")
        || UserDefaults.standard.bool(forKey: "ForceProMode")
    #endif

    init() {
        #if DEBUG
        if forceProMode {
            isPro = true
            BarnHubLogger.info("ForceProMode enabled")
        }
        #endif
        updateTask = Task { [weak self] in
            await self?.listenForUpdates()
        }
        setupTask = Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    deinit {
        updateTask?.cancel()
        setupTask?.cancel()
    }

    func loadProducts() async {
        productsLoadFailed = false
        do {
            let fetched = try await Product.products(for: Self.productIDs)
            products = fetched.sorted { $0.price < $1.price }
            if fetched.isEmpty {
                productsLoadFailed = true
                BarnHubLogger.warning("No products returned from App Store for IDs=\(Self.productIDs)")
            } else {
                BarnHubLogger.success("Loaded \(fetched.count) products")
            }
        } catch {
            productsLoadFailed = true
            BarnHubLogger.error("Failed to load products: \(error.localizedDescription)")
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
                BarnHubLogger.success("Purchase completed productID=\(product.id)")
                return true
            case .userCancelled:
                BarnHubLogger.info("Purchase cancelled by user")
                return false
            case .pending:
                BarnHubLogger.info("Purchase pending approval")
                return false
            @unknown default:
                return false
            }
        } catch {
            BarnHubLogger.error("Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            BarnHubLogger.success("Restore completed isPro=\(isPro)")
            return isPro
        } catch {
            BarnHubLogger.error("Restore failed: \(error.localizedDescription)")
            return false
        }
    }

    func refreshEntitlements() async {
        #if DEBUG
        if forceProMode { return }
        #endif
        let (foundPro, foundLifetime) = await { () -> (Bool, Bool) in
            var sub = false
            var lifetime = false
            for await result in SKTransaction.currentEntitlements {
                guard let txn = try? checkVerified(result) else { continue }
                if txn.productID == Self.lifetimeID {
                    lifetime = true
                    break
                }
                if Self.subscriptionIDs.contains(txn.productID) {
                    sub = true
                }
            }
            return (lifetime || sub, lifetime)
        }()
        await MainActor.run {
            hasLifetime = foundLifetime
            if isPro != foundPro { isPro = foundPro }
        }
    }

    private func listenForUpdates() async {
        for await result in SKTransaction.updates {
            guard let txn = try? checkVerified(result) else { continue }
            await txn.finish()
            await refreshEntitlements()
            BarnHubLogger.info("Transaction update productID=\(txn.productID)")
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }
}
