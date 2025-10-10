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
    
    // Subscription product IDs
    let monthlyProductID = "com.grc.chess3d.monthly"
    let yearlyProductID = "com.grc.chess3d.yearly"
    
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
        guard !products.isEmpty else {
            await loadProducts()
            return
        }
        
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == monthlyProductID || transaction.productID == yearlyProductID {
                    await updateSubscriptionStatus(transaction: transaction)
                    return
                }
            }
        }
        
        // No active subscription found
        subscriptionStatus = .none
        hasActiveSubscription = false
        isInTrialPeriod = false
    }
    
    private func updateSubscriptionStatus(transaction: StoreKit.Transaction) async {
        let now = Date()
        let expirationDate = transaction.expirationDate ?? now
        
        if expirationDate > now {
            // Active subscription
            subscriptionStatus = .active
            hasActiveSubscription = true
            
            // Check if in trial period
            let originalPurchaseDate = transaction.originalPurchaseDate
            let trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: originalPurchaseDate) ?? originalPurchaseDate
            isInTrialPeriod = now < trialEndDate
            
            if isInTrialPeriod {
                let daysRemaining = Calendar.current.dateComponents([.day], from: now, to: trialEndDate).day ?? 0
                trialDaysRemaining = max(0, daysRemaining)
            }
        } else {
            // Expired subscription
            subscriptionStatus = .expired
            hasActiveSubscription = false
            isInTrialPeriod = false
        }
    }
    
    // MARK: - Purchase Methods
    
    func startFreeTrial() async {
        guard let monthlyProduct = products.first(where: { $0.id == monthlyProductID }) else {
            errorMessage = "Subscription not available"
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
            errorMessage = "Failed to start free trial"
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
