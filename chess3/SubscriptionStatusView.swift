//
//  SubscriptionStatusView.swift
//  chess3
//
//  Created by Gareth Costa on 17/10/2025.
//

import SwiftUI
import StoreKit

struct SubscriptionStatusView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Premium Active")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if subscriptionManager.isInTrialPeriod {
                        Text("Free Trial - \(subscriptionManager.trialDaysRemaining) days remaining")
                            .font(.title3)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    } else {
                        Text("Premium Subscription Active")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.top)
                
                // Features List
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "gamecontroller.fill", text: "Challenge Friends Via Game Center")
                    FeatureRow(icon: "brain.head.profile", text: "Test Yourself Against AI opponent")
                    FeatureRow(icon: "cube.transparent", text: "Rotating Boards for Play On One Device")
                    FeatureRow(icon: "chart.bar.fill", text: "AI game statistics")
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Restore Purchases") {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .disabled(subscriptionManager.isLoading)
                    
                    if subscriptionManager.isInTrialPeriod {
                        Text("Your free trial will automatically convert to a paid subscription unless cancelled.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Terms and Privacy
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our Terms of Service and Privacy Policy")
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
            .frame(minWidth: 400, maxWidth: 500, minHeight: 500, maxHeight: 600)
            .frame(width: 500, height: 600)
            .background(Color(.windowBackgroundColor))
            .padding()
            .navigationTitle("Premium Status")
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
                    .foregroundColor(.green)
                    .frame(width: 32)
                
                Text(text)
                    .font(.title3)
                
                Spacer()
            }
        }
    }
}

#Preview {
    SubscriptionStatusView(subscriptionManager: SubscriptionManager())
}



