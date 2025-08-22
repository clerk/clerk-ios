//
//  RevenueCatManager.swift
//  ClerkRevCat
//
//  Created by Mike Pitre on 8/19/25.
//

import Foundation
import RevenueCat

/// Manager class for handling RevenueCat operations and subscription state
@MainActor
@Observable
class RevenueCatManager {
    
    // MARK: - Observable Properties
    
    var currentOffering: Offering?
    var customerInfo: CustomerInfo?
    var errorMessage: String?
    
    // MARK: - Singleton
    
    static let shared = RevenueCatManager()
    
    // MARK: - Initialization
    
    init() {
        setupRevenueCat()
    }
    
    // MARK: - Setup
    
    /// Configure RevenueCat with API key
    private func setupRevenueCat() {
        Purchases.logLevel = .debug  // Enable debug logging for development
        Purchases.configure(withAPIKey: "YOUR_REVENUECAT_API_KEY")
        
        Task {
            await loadCustomerInfo()
            await loadCurrentOffering()
        }
    }
    
    // MARK: - User Management
    
    /// Login user with Clerk user ID
    func loginUser(withClerkUserId clerkUserId: String) async {
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(clerkUserId)
            self.customerInfo = customerInfo
        } catch {
            self.errorMessage = "Failed to login user: \(error.localizedDescription)"
        }
    }
    
    /// Logout current user
    func logoutUser() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
        } catch {
            self.errorMessage = "Failed to logout user: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Data Loading
    
    /// Load customer info from RevenueCat
    func loadCustomerInfo() async {
        self.errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
        } catch {
            self.errorMessage = "Failed to load customer info: \(error.localizedDescription)"
        }
    }
    
    /// Load current offering from RevenueCat
    func loadCurrentOffering() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.currentOffering = offerings.current
        } catch {
            self.errorMessage = "Failed to load offerings: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Purchase Management
    
    /// Restore purchases
    func restorePurchases() async {
        self.errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
        } catch {
            self.errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }
        
    // MARK: - Helper Methods
    
    /// Check if user has access to premium features
    var hasPremiumAccess: Bool {
        return customerInfo?.entitlements.all["premium"]?.isActive == true
    }
    
    /// Get active entitlements
    var activeEntitlements: [String] {
        guard let customerInfo = customerInfo else { return [] }
        return Array(customerInfo.entitlements.active.keys)
    }
}
