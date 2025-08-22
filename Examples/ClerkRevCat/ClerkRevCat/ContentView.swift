//
//  ContentView.swift
//  ClerkRevCat
//
//  Created by Mike Pitre on 8/19/25.
//

import Clerk
import RevenueCat
import RevenueCatUI
import SwiftUI

struct ContentView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(RevenueCatManager.self) private var revenueCatManager
    @State private var showingPaywall = false
    @State private var showingAuth = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HeaderView()

                    // Free Content Section
                    FreeContentSection()

                    // Premium Content Section
                    PremiumContentSection(
                        showPaywall: $showingPaywall
                    )

                    // Subscription Status
                    SubscriptionStatusView()
                }
                .padding()
            }
            .navigationTitle("ClerkRevCat Demo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if clerk.user != nil {
                        UserButton()
                            .frame(width: 36, height: 36)
                    } else {
                        Button("Sign In") {
                            showingAuth = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPaywall, content: {
                PaywallView()
                    .onPurchaseCompleted { revenueCatManager.customerInfo = $0 }
                    .onRestoreCompleted { revenueCatManager.customerInfo = $0 }
            })
            .sheet(isPresented: $showingAuth) {
                AuthView()
            }
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Clerk + RevenueCat Demo")
                .font(.title2)
                .fontWeight(.bold)

            Text("Demonstrating authentication-gated premium content")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
}

// MARK: - Free Content Section

struct FreeContentSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(.green)
                Text("Free Content")
                    .font(.headline)
                Spacer()
            }

            FreeContentCard(title: "Free Article")
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FreeContentCard: View {
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.title2)
                .foregroundColor(.green)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

// MARK: - Premium Content Section

struct PremiumContentSection: View {
    @Environment(RevenueCatManager.self) private var revenueCatManager
    @Binding var showPaywall: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.orange)
                Text("Premium Content")
                    .font(.headline)
                Spacer()

                if revenueCatManager.hasPremiumAccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            PremiumContentCard(
                title: "Premium Article",
                isUnlocked: revenueCatManager.hasPremiumAccess,
                showPaywall: $showPaywall
            )
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PremiumContentCard: View {
    let title: String
    let isUnlocked: Bool
    @Binding var showPaywall: Bool

    var body: some View {
        Button(action: {
            if !isUnlocked {
                showPaywall = true
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: isUnlocked ? "doc.text.fill" : "lock.fill")
                        .font(.title2)
                        .foregroundColor(isUnlocked ? .orange : .gray)

                    if !isUnlocked {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .offset(x: 12, y: -12)
                    }
                }

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(isUnlocked ? Color.white : Color.gray.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isUnlocked ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(radius: isUnlocked ? 2 : 0)
            .animation(.bouncy, value: isUnlocked)
        }
        .disabled(isUnlocked)
    }
}

// MARK: - Subscription Status View

struct SubscriptionStatusView: View {
    @Environment(RevenueCatManager.self) private var revenueCatManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.blue)
                Text("Subscription Status")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Status:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(revenueCatManager.hasPremiumAccess ? "Active" : "Inactive")
                        .foregroundColor(revenueCatManager.hasPremiumAccess ? .green : .red)
                        .fontWeight(.semibold)
                }

                if !revenueCatManager.activeEntitlements.isEmpty {
                    HStack {
                        Text("Entitlements:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(revenueCatManager.activeEntitlements.joined(separator: ", "))
                            .foregroundColor(.secondary)
                    }
                }

                Button("Restore Purchases") {
                    Task {
                        await revenueCatManager.restorePurchases()
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }

            if let errorMessage = revenueCatManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
        .environment(RevenueCatManager.shared)
        .environment(Clerk.shared)
}
