//
//  SubscriptionView.swift
//  chess3ios
//
//  Created by Gareth Costa on 13/8/2025.
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: String = "monthly"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow)
                    
                    Text("Chess 3D Premium")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Unlock all features with a free trial")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Features List
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "gamecontroller.fill", text: "Full Game Center multiplayer")
                    FeatureRow(icon: "brain.head.profile", text: "Advanced AI opponents")
                  //  FeatureRow(icon: "cube.transparent", text: "All 3D board configurations")
                    FeatureRow(icon: "chart.bar.fill", text: "Detailed game statistics")
                 //   FeatureRow(icon: "paintbrush.fill", text: "Custom board themes")
                }
                .padding(.horizontal)
                
                // Subscription Status
                if subscriptionManager.hasActiveSubscription {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(subscriptionManager.getTrialDescription())
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                } else {
                    // Subscription Options
                    VStack(spacing: 12) {
                        // Product Selection
                        VStack(spacing: 8) {
                            SubscriptionOptionView(
                                product: subscriptionManager.getMonthlyProduct(),
                                isSelected: selectedProduct == "monthly",
                                isRecommended: true
                            ) {
                                selectedProduct = "monthly"
                            }
                            
                            SubscriptionOptionView(
                                product: subscriptionManager.getYearlyProduct(),
                                isSelected: selectedProduct == "yearly",
                                isRecommended: false
                            ) {
                                selectedProduct = "yearly"
                            }
                        }
                        
                        // Action Buttons
                        VStack(spacing: 8) {
                            Button(action: {
                                Task {
                                    if selectedProduct == "monthly" {
                                        await subscriptionManager.startFreeTrial()
                                    } else {
                                        await subscriptionManager.purchaseSubscription(productID: subscriptionManager.yearlyProductID)
                                    }
                                }
                            }) {
                                HStack {
                                    if subscriptionManager.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "star.fill")
                                    }
                                    Text(subscriptionManager.isInTrialPeriod ? "Continue Trial" : "Start Free Trial")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .disabled(subscriptionManager.isLoading)
                            
                            Button("Restore Purchases") {
                                Task {
                                    await subscriptionManager.restorePurchases()
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .disabled(subscriptionManager.isLoading)
                        }
                    }
                }
                
                // Error Message
                if let errorMessage = subscriptionManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Terms and Privacy
                VStack(spacing: 4) {
                    Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 16) {
                        Button("Terms of Service") {
                            // Open terms
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                        
                        Button("Privacy Policy") {
                            // Open privacy policy
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await subscriptionManager.loadProducts()
                await subscriptionManager.checkSubscriptionStatus()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct SubscriptionOptionView: View {
    let product: Product?
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product?.displayName ?? "Loading...")
                            .font(.headline)
                        
                        if isRecommended {
                            Text("BEST VALUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    Text(product?.displayPrice ?? "Loading...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SubscriptionView()
}
