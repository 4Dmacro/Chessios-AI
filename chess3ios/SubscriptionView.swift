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
            ScrollView {
                VStack(spacing: 12) {
                    // Header
                    VStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.yellow)
                        
                        Text("Chess 3D")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Unlock all features with a free trial")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    
                    // Features List
                    VStack(alignment: .leading, spacing: 6) {
                        FeatureRow(icon: "gamecontroller.fill", text: "Challenge Friends Via Game Center")
                        FeatureRow(icon: "brain.head.profile", text: "Test Yourself Against AI opponents")
                        FeatureRow(icon: "cube.transparent", text: "Rotating Boards for Play On One Device")
                        FeatureRow(icon: "chart.bar.fill", text: "AI game statistics")
                    }
                    .padding(.horizontal, 16)
                
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
                    VStack(spacing: 8) {
                        // Product Selection
                        VStack(spacing: 6) {
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
                        .padding(.horizontal, 20)
                        
                        // Action Buttons
                        VStack(spacing: 6) {
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
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                    }
                                    Text(subscriptionManager.isInTrialPeriod ? "Continue Trial" : "Start Free Trial")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .disabled(subscriptionManager.isLoading)
                            .padding(.horizontal, 20)
                            
                            Button("Restore Purchases") {
                                Task {
                                    await subscriptionManager.restorePurchases()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .disabled(subscriptionManager.isLoading)
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                // Error Message
                if let errorMessage = subscriptionManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                }
                
                // Terms and Privacy
                VStack(spacing: 4) {
                    Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    HStack(spacing: 12) {
                        Button("Terms of Service") {
                            if let url = URL(string: "https://www.3dchesscubed.com/terms-of-service") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                        
                        Button("Privacy Policy") {
                            if let url = URL(string: "https://www.3dchesscubed.com/app-privacy-policy") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 16)
                }
            }
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
            
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
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(product?.displayName ?? "Loading...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                     //   if isRecommended {
                      //      Text("BEST")
                      //          .font(.caption2)
                      //          .fontWeight(.bold)
                      //          .foregroundColor(.white)
                      //          .padding(.horizontal, 4)
                       //         .padding(.vertical, 1)
                       //         .background(Color.orange)
                      //          .cornerRadius(3)
                      //  }
                        
                        Spacer()
                    }
                    
                    Text(product?.displayPrice ?? "Loading...")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SubscriptionView()
}
