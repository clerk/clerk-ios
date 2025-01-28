//
//  User+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation

extension User {
    
    /// The user's full name.
    public var fullName: String? {
        let joinedString = [firstName, lastName]
            .compactMap { $0 }
            .filter({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return joinedString.isEmpty ? nil : joinedString
    }
    
    var initials: String? {
        let joinedString = [firstName, lastName]
            .compactMap { $0?.first }
            .map { String($0) }
            .joined()
        
        return joinedString.isEmpty ? nil : joinedString
    }
    
    var identifier: String? {
        username ?? primaryEmailAddress?.emailAddress ?? primaryPhoneNumber?.phoneNumber
    }
    
    @MainActor
    var unconnectedProviders: [OAuthProvider] {
        guard let allExternalProviders = Clerk.shared.environment.userSettings?.socialProviders.sorted() else { return [] }
        let verifiedExternalProviders = verifiedExternalAccounts.compactMap { $0.oauthProvider }
        return allExternalProviders.filter { !verifiedExternalProviders.contains($0) }
    }
    
    @MainActor
    var availableSecondFactors: [String: Clerk.Environment.UserSettings.AttributesConfig] {
        Clerk.shared.environment.userSettings?.availableSecondFactors(user: self) ?? [:]
    }
    
    var phoneNumbersAvailableForSecondFactor: [PhoneNumber] {
        phoneNumbers.filter { !$0.reservedForSecondFactor }
    }
    
    var mfaPhones: [PhoneNumber] {
        phoneNumbers.filter { $0.verification?.status == .verified && $0.reservedForSecondFactor }
    }
    
}
