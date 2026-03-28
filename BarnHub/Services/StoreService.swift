import CryptoKit
import Foundation
import Security
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

    /// SHA-256 hash of the accepted secret pro code
    private static let secretProCodeHash = "102eed4f5449cd2346d3e867dac01aca0f65d95e8295b543f415af9c3714ba93"
    private static let secretProKey = "SecretProUnlocked"
    private static let proOverrideDisabledKey = "ProOverrideDisabled"

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var annualProduct: Product? { products.first { $0.id == Self.annualID } }
    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }
    private(set) var hasLifetime = false

    var hasSecretPro: Bool { Self.keychainBool(forKey: Self.secretProKey) }

    var isProOverrideDisabled: Bool {
        get { Self.keychainBool(forKey: Self.proOverrideDisabledKey) }
        set {
            Self.setKeychainBool(newValue, forKey: Self.proOverrideDisabledKey)
            Task { await refreshEntitlements() }
        }
    }

    private static func keychainBool(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "net.shadowpuppet.BarnBook",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, !data.isEmpty else { return false }
        return data[0] != 0
    }

    /// Writes a boolean flag to the keychain. Returns true if the write succeeded.
    @discardableResult
    private static func setKeychainBool(_ value: Bool, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "net.shadowpuppet.BarnBook",
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = Data([value ? 1 : 0])
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            BarnHubLogger.error("Keychain write failed for key '\(key)': status \(status)")
        }
        return status == errSecSuccess
    }

    /// One-time migration: if UserDefaults contains secret-pro flags from a pre-Keychain
    /// build, copy them into the Keychain and remove the UserDefaults entries so the
    /// user doesn't lose their unlock after upgrading.
    private static func migrateUserDefaultsToKeychain() {
        let defaults = UserDefaults.standard
        let udSecretKey = "SecretProUnlocked"
        let udOverrideKey = "ProOverrideDisabled"

        // Only migrate if Keychain has no value yet but UserDefaults does.
        if !keychainBool(forKey: secretProKey),
           defaults.object(forKey: udSecretKey) != nil {
            let wasUnlocked = defaults.bool(forKey: udSecretKey)
            let wasDisabled = defaults.bool(forKey: udOverrideKey)
            if setKeychainBool(wasUnlocked, forKey: secretProKey)
                && setKeychainBool(wasDisabled, forKey: proOverrideDisabledKey) {
                defaults.removeObject(forKey: udSecretKey)
                defaults.removeObject(forKey: udOverrideKey)
                BarnHubLogger.info("Migrated secret-pro flags from UserDefaults to Keychain")
            }
        }
    }

    func redeemSecretCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = SHA256.hash(data: Data(trimmed.utf8))
        let hexHash = hash.compactMap { String(format: "%02x", $0) }.joined()
        guard hexHash == Self.secretProCodeHash else {
            BarnHubLogger.warning("Invalid secret code attempted")
            return false
        }
        let wrote = Self.setKeychainBool(true, forKey: Self.secretProKey)
            && Self.setKeychainBool(false, forKey: Self.proOverrideDisabledKey)
        guard wrote else {
            BarnHubLogger.error("Secret pro code keychain write failed — unlock not persisted")
            return false
        }
        isPro = true
        BarnHubLogger.success("Secret pro code redeemed")
        return true
    }

    #if DEBUG
    private let forceProMode = ProcessInfo.processInfo.arguments.contains("-ForceProMode")
        || UserDefaults.standard.bool(forKey: "ForceProMode")
    #endif

    init() {
        Self.migrateUserDefaultsToKeychain()
        #if DEBUG
        if forceProMode {
            isPro = true
            BarnHubLogger.info("ForceProMode enabled")
        }
        #endif
        if hasSecretPro && !isProOverrideDisabled {
            isPro = true
            BarnHubLogger.info("Secret pro code active")
        }
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
        if hasSecretPro && !isProOverrideDisabled {
            await MainActor.run { if !isPro { isPro = true } }
            return
        }
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
