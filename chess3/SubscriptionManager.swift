//
//  SubscriptionManager.swift
//  chess3
//
//  Created by Gareth Costa on 13/8/2025.
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var isInTrialPeriod = false
    @Published var trialDaysRemaining = 0
    @Published var hasActiveSubscription = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Prevent rapid updates that cause layout recursion
    private var updateTimer: Timer?
    
    // Subscription product IDs
    let monthlyProductID = "com.grc.chess3d.submth"
    let yearlyProductID = "com.grc.chess3d.sub1yr"
    
    private var products: [Product] = []
    private var updateListenerTask: Task<Void, Error>? = nil
    
    init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products and check subscription status
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Debug Methods
    
    func resetSubscriptionForTesting() {
        print("🔄 DEBUG: Resetting subscription status for testing")
        subscriptionStatus = .unknown
        isInTrialPeriod = false
        trialDaysRemaining = 0
        hasActiveSubscription = false
        errorMessage = nil
        print("🔄 DEBUG: Subscription status reset - Premium button should now be visible")
    }
    
    func forceRefreshSubscriptionStatus() {
        print("🔄 SubscriptionManager: Force refreshing subscription status")
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    // Debounced update to prevent layout recursion
    private func debouncedUpdate(updates: @escaping () -> Void) {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            updates()
        }
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        do {
            let productIDs = [monthlyProductID, yearlyProductID]
            products = try await Product.products(for: productIDs)
            print("🛒 Loaded \(products.count) subscription products")
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = "Failed to load subscription options"
        }
    }
    
    // MARK: - Subscription Status
    
    func checkSubscriptionStatus() async {
        print("🔍 SubscriptionManager: Checking subscription status...")
        
        guard !products.isEmpty else {
            print("🔍 SubscriptionManager: No products loaded, loading products first")
            await loadProducts()
            return
        }
        
        var foundActiveSubscription = false
        
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                print("🔍 SubscriptionManager: Found transaction for product: \(transaction.productID)")
                if transaction.productID == monthlyProductID || transaction.productID == yearlyProductID {
                    print("🔍 SubscriptionManager: This is our subscription product")
                    await updateSubscriptionStatus(transaction: transaction)
                    foundActiveSubscription = true
                    return
                }
            }
        }
        
        if !foundActiveSubscription {
            print("🔍 SubscriptionManager: No active subscription found")
            // No active subscription found - update on main thread
            await MainActor.run {
                debouncedUpdate {
                    self.subscriptionStatus = .none
                    self.hasActiveSubscription = false
                    self.isInTrialPeriod = false
                    print("🔍 SubscriptionManager: UI updated on main thread (no subscription, debounced)")
                }
            }
        }
    }
    
    private func updateSubscriptionStatus(transaction: StoreKit.Transaction) async {
        let now = Date()
        let expirationDate = transaction.expirationDate ?? now
        
        print("🔍 SubscriptionManager: Transaction details:")
        print("🔍 - Product ID: \(transaction.productID)")
        print("🔍 - Original Purchase Date: \(transaction.originalPurchaseDate)")
        print("🔍 - Expiration Date: \(expirationDate)")
        print("🔍 - Current Date: \(now)")
        print("🔍 - Is Expired: \(expirationDate <= now)")
        
        if expirationDate > now {
            // Active subscription
            print("🔍 SubscriptionManager: Active subscription found")
            
            // Check if in trial period
            let originalPurchaseDate = transaction.originalPurchaseDate
            let trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: originalPurchaseDate) ?? originalPurchaseDate
            let isInTrial = now < trialEndDate
            
            print("🔍 SubscriptionManager: Trial period check:")
            print("🔍 - Original Purchase: \(originalPurchaseDate)")
            print("🔍 - Trial End Date: \(trialEndDate)")
            print("🔍 - Is In Trial: \(isInTrial)")
            
            let daysRemaining = isInTrial ? max(0, Calendar.current.dateComponents([.day], from: now, to: trialEndDate).day ?? 0) : 0
            print("🔍 SubscriptionManager: Trial days remaining: \(daysRemaining)")
            
            // Update on main thread with debouncing to prevent layout recursion
            await MainActor.run {
                debouncedUpdate {
                    self.subscriptionStatus = .active
                    self.hasActiveSubscription = true
                    self.isInTrialPeriod = isInTrial
                    self.trialDaysRemaining = daysRemaining
                    print("🔍 SubscriptionManager: UI updated on main thread (debounced)")
                }
            }
        } else {
            // Expired subscription
            print("🔍 SubscriptionManager: Expired subscription")
            await MainActor.run {
                debouncedUpdate {
                    self.subscriptionStatus = .expired
                    self.hasActiveSubscription = false
                    self.isInTrialPeriod = false
                    print("🔍 SubscriptionManager: UI updated on main thread (expired, debounced)")
                }
            }
        }
        
        print("🔍 SubscriptionManager: Final status - hasActiveSubscription: \(hasActiveSubscription), isInTrialPeriod: \(isInTrialPeriod)")
    }
    
    // MARK: - Purchase Methods
    
    func startFreeTrial() async {
        guard let monthlyProduct = products.first(where: { $0.id == monthlyProductID }) else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await monthlyProduct.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await checkSubscriptionStatus()
                    print("✅ Free trial started successfully")
                }
            case .userCancelled:
                print("ℹ️ User cancelled purchase")
            case .pending:
                print("⏳ Purchase pending")
            @unknown default:
                print("❓ Unknown purchase result")
            }
        } catch {
            print("❌ Purchase failed: \(error)")
        }
        
        isLoading = false
    }
    
    func purchaseSubscription(productID: String) async {
        guard let product = products.first(where: { $0.id == productID }) else {
            errorMessage = "Product not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await checkSubscriptionStatus()
                    print("✅ Subscription purchased successfully")
                }
            case .userCancelled:
                print("ℹ️ User cancelled purchase")
            case .pending:
                print("⏳ Purchase pending")
            @unknown default:
                print("❓ Unknown purchase result")
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            errorMessage = "Failed to purchase subscription"
        }
        
        isLoading = false
    }
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("✅ Purchases restored")
        } catch {
            print("❌ Restore failed: \(error)")
            errorMessage = "Failed to restore purchases"
        }
        
        isLoading = false
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await MainActor.run {
                        return try self.checkVerified(result)
                    }
                    await transaction.finish()
                    await self.checkSubscriptionStatus()
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Helper Methods
    
    func getMonthlyProduct() -> Product? {
        return products.first(where: { $0.id == monthlyProductID })
    }
    
    func getYearlyProduct() -> Product? {
        return products.first(where: { $0.id == yearlyProductID })
    }
    
    func getFormattedPrice(for productID: String) -> String {
        guard let product = products.first(where: { $0.id == productID }) else {
            return "N/A"
        }
        return product.displayPrice
    }
    
    func getTrialDescription() -> String {
        if isInTrialPeriod {
            return "Free trial: \(trialDaysRemaining) days remaining"
        } else if hasActiveSubscription {
            return "Premium active"
        } else {
            return "Start 7-day free trial"
        }
    }
}

// MARK: - Enums

enum SubscriptionStatus {
    case unknown
    case none
    case active
    case expired
    case trial
}

enum StoreError: Error {
    case failedVerification
    case unknown
}
