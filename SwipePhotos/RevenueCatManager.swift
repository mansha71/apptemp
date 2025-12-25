import SwiftUI
import RevenueCat
import Combine

@MainActor
class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var isSubscribed = false
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var currentOffering: Offering?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let entitlementID = "plus" // Your entitlement ID from dashboard
    
    private override init() {
        super.init()
        print("")
        print("🚀 ============ RevenueCatManager INIT ============")
        print("🚀 isSubscribed initial value = \(isSubscribed)")
        // Set as delegate to listen for updates
        Purchases.shared.delegate = self
        print("🚀 Set Purchases.shared.delegate")
        // Check initial subscription status for anonymous user
        Task {
            print("🚀 Calling initial checkSubscriptionStatus...")
            await checkSubscriptionStatus()
            print("🚀 Initial checkSubscriptionStatus done. isSubscribed = \(isSubscribed)")
        }
        print("🚀 ================================================")
    }
    
    // MARK: - Setup with User ID
    /// Call this after user logs in with their Supabase user ID
    func setupWithUserID(_ userID: String) async {
        // IMPORTANT: Wait for logIn to complete before checking status
        // Using withCheckedContinuation to convert callback to async/await
        do {
            let customerInfo: CustomerInfo = try await withCheckedThrowingContinuation { continuation in
                Purchases.shared.logIn(userID) { customerInfo, _, error in
                    if let error = error {
                        print("❌ Error setting RevenueCat user: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let customerInfo = customerInfo {
                        print("✅ RevenueCat logIn completed for user: \(userID)")
                        continuation.resume(returning: customerInfo)
                    } else {
                        continuation.resume(throwing: NSError(domain: "RevenueCat", code: -1, userInfo: [NSLocalizedDescriptionKey: "No customer info returned"]))
                    }
                }
            }
            
            // Now that login is complete, update state with the returned customerInfo
            self.customerInfo = customerInfo
            self.isSubscribed = customerInfo.entitlements[entitlementID]?.isActive == true
            print("📊 Subscription status after login: isSubscribed = \(self.isSubscribed)")
            
            // Log all entitlements for debugging
            for (key, entitlement) in customerInfo.entitlements.all {
                print("  - \(key): active=\(entitlement.isActive)")
            }
            
        } catch {
            print("❌ Failed to log in to RevenueCat: \(error.localizedDescription)")
            // On error, ensure user is NOT subscribed (fail-safe)
            self.isSubscribed = false
        }
        
        // Load offerings (can happen after login completes)
        await loadOfferings()
    }
    
    // MARK: - Check Subscription Status
    func checkSubscriptionStatus() async {
        print("")
        print("🔍 ====== checkSubscriptionStatus START ======")
        do {
            print("🔍 Fetching customerInfo from Purchases.shared...")
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            
            print("🔍 CustomerInfo received. Entitlements:")
            if customerInfo.entitlements.all.isEmpty {
                print("🔍   (no entitlements)")
            }
            for (key, entitlement) in customerInfo.entitlements.all {
                print("🔍   - \(key): active=\(entitlement.isActive)")
            }
            
            // Check if user has the premium entitlement
            let hasEntitlement = customerInfo.entitlements[entitlementID]?.isActive == true
            print("🔍 Checking entitlementID '\(entitlementID)': isActive = \(hasEntitlement)")
            self.isSubscribed = hasEntitlement
            errorMessage = nil
            print("🔍 Set isSubscribed = \(self.isSubscribed)")
            
        } catch {
            print("❌ checkSubscriptionStatus error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isSubscribed = false
        }
        print("🔍 ====== checkSubscriptionStatus END ======")
        print("")
    }
    
    // MARK: - Load Offerings
    func loadOfferings() async {
        print("")
        print("📦 ====== loadOfferings START ======")
        do {
            print("📦 Fetching offerings from Purchases.shared...")
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            self.currentOffering = offerings.current
            
            print("📦 Offerings received:")
            print("📦   - All offerings count: \(offerings.all.count)")
            if let current = offerings.current {
                print("📦   - Current offering: \(current.identifier)")
                print("📦   - Packages in current: \(current.availablePackages.map { $0.identifier })")
            } else {
                print("📦   - ⚠️ NO CURRENT OFFERING!")
            }
            
        } catch {
            print("❌ loadOfferings error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        print("📦 ====== loadOfferings END ======")
        print("")
    }
    
    // MARK: - Make Purchase
    func purchase(package: Package) async -> Bool {
        isLoading = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if !result.userCancelled {
                await checkSubscriptionStatus()
                isLoading = false
                return true
            } else {
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            self.isSubscribed = customerInfo.entitlements[entitlementID]?.isActive == true
            errorMessage = nil
            
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() async {
        do {
            _ = try await Purchases.shared.logOut()
            self.isSubscribed = false
            self.customerInfo = nil
            self.offerings = nil
            self.currentOffering = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete User
    /// Deletes the user's data from RevenueCat
    /// This anonymizes the user by logging them out
    /// For complete data deletion, you need to call RevenueCat's REST API from your backend
    func deleteUser(appUserID: String) async throws {
        // RevenueCat doesn't expose a deleteCustomer() method in the SDK
        // For security reasons, customer deletion should be done via:
        // 1. Your backend calling RevenueCat's REST API with your Secret API Key
        // 2. Or manually through the RevenueCat dashboard

        // For now, we log out the user which anonymizes them
        do {
            // Log out the user (this anonymizes them in RevenueCat)
            _ = try await Purchases.shared.logOut()

            // Clear local state
            self.isSubscribed = false
            self.customerInfo = nil
            self.offerings = nil
            self.currentOffering = nil

            print("✓ User logged out from RevenueCat (anonymized)")
            print("ℹ️ For complete GDPR deletion, call RevenueCat REST API: DELETE /v1/subscribers/\(appUserID)")

        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    /// Called when subscription status changes
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.isSubscribed = customerInfo.entitlements[self.entitlementID]?.isActive == true
        }
    }
}
