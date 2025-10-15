//
//  SubscriptionView.swift
//  chess3
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
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                    
                    Text("Chess 3D")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Unlock all features with a free trial")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Features List
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "gamecontroller.fill", text: "Challenge Friends Via Game Center")
                    FeatureRow(icon: "brain.head.profile", text: "Test Yourself Against AI opponent")
                    FeatureRow(icon: "cube.transparent", text: "Rotating Boards for Play On One Device")
                    FeatureRow(icon: "chart.bar.fill", text: "AI game statistics")
                    //  FeatureRow(icon: "paintbrush.fill", text: "Custom board themes")
                }
                .padding(.horizontal, 40)
                
                // Subscription Status
                if subscriptionManager.hasActiveSubscription {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text(subscriptionManager.getTrialDescription())
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                } else {
                    // Subscription Options
                    VStack(spacing: 16) {
                        // Product Selection
                        VStack(spacing: 12) {
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
                        VStack(spacing: 12) {
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
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .disabled(subscriptionManager.isLoading)
                            .frame(maxWidth: 300)
                            
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
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Terms and Privacy
                VStack(spacing: 8) {
                    Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    HStack(spacing: 24) {
                        Button("Terms of Service") {
                            if let url = URL(string: "https://www.3dchesscubed.com/terms-of-service") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Button("Privacy Policy") {
                            if let url = URL(string: "https://www.3dchesscubed.com/app-privacy-policy") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.bottom)
                
            }
            .frame(width: 500, height: 600)
            .padding()
            .onAppear {
                Task {
                    await subscriptionManager.loadProducts()
                    await subscriptionManager.checkSubscriptionStatus()
                }
            }
            .navigationTitle("Premium")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    struct FeatureRow: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 32)
                
                Text(text)
                    .font(.title3)
                
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(product?.displayName ?? "Loading...")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                         //   if isRecommended {
                          //      Text("BEST VALUE")
                          //          .font(.caption)
                           //         .fontWeight(.bold)
                          //          .foregroundColor(.white)
                          //          .padding(.horizontal, 8)
                           //         .padding(.vertical, 4)
                          //          .background(Color.orange)
                          //          .cornerRadius(6)
                          //  }
                            
                            Spacer()
                        }
                        
                        Text(product?.displayPrice ?? "Loading...")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(product?.displayName ?? "Loading...")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                       // if isRecommended {
                       //     Text("BEST VALUE")
                        //        .font(.caption)
                         //       .fontWeight(.bold)
                         //       .foregroundColor(.white)
                         //       .padding(.horizontal, 8)
                         //       .padding(.vertical, 4)
                         //       .background(Color.orange)
                         //       .cornerRadius(6)
                       // }
                        
                        Spacer()
                    }
                    
                    Text(product?.displayPrice ?? "Loading...")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
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


