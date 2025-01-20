//
//  User+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation
import Clerk

extension User {
    
    /// A boolean that returns true if the user is signed in.
    @MainActor
    public var isSignedIn: Bool {
        let activeUserIds = Clerk.shared.client?.activeSessions.compactMap(\.user?.id) ?? []
        return activeUserIds.contains(id)
    }
    
    /// The user's full name.
    public var fullName: String? {
        let joinedString = [firstName, lastName]
            .compactMap { $0 }
            .filter({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return joinedString.isEmpty ? nil : joinedString
    }
    
    /// Information about the user's primary email address.
    public var primaryEmailAddress: EmailAddress? {
        guard let primaryEmailAddressId else { return nil }
        return emailAddresses.first(where: { $0.id == primaryEmailAddressId })
    }
    
    /// Information about the user's primary phone number.
    public var primaryPhoneNumber: PhoneNumber? {
        guard let primaryPhoneNumberId else { return nil }
        return phoneNumbers.first(where: { $0.id == primaryPhoneNumberId })
    }
    
    /// A getter for the user's list of verified external accounts.
    public var verifiedExternalAccounts: [ExternalAccount] {
        externalAccounts.filter { $0.verification?.status == .verified }
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
    
    func identifierBelongsToUser(identifier: String) -> Bool {
        let allIdentifiers = emailAddresses.map(\.emailAddress) + phoneNumbers.map(\.phoneNumber) + [username]
        return allIdentifiers.contains(identifier)
    }
    
    @MainActor
    var unconnectedProviders: [OAuthProvider] {
        guard let environment = Clerk.shared.environment else { return []}
        let allExternalProviders = environment.userSettings.socialProviders.sorted()
        let verifiedExternalProviders = verifiedExternalAccounts.compactMap { $0.oauthProvider }
        return allExternalProviders.filter { !verifiedExternalProviders.contains($0) }
    }
    
    @MainActor
    var availableSecondFactors: [String: Clerk.Environment.UserSettings.AttributesConfig] {
        guard let environment = Clerk.shared.environment else { return [:] }
        return environment.userSettings.availableSecondFactors(user: self)
    }
    
    var phoneNumbersAvailableForSecondFactor: [PhoneNumber] {
        phoneNumbers.filter { !$0.reservedForSecondFactor }
    }
    
    var mfaPhones: [PhoneNumber] {
        phoneNumbers.filter { $0.verification?.status == .verified && $0.reservedForSecondFactor }
    }
    
}

extension User {
    
    static var mock: User {
        
        .init(
            id: UUID().uuidString,
            firstName: "First",
            lastName: "Last",
            username: "Username",
            imageUrl: "",
            hasImage: false,
            primaryEmailAddressId: nil,
            emailAddresses: [],
            primaryPhoneNumberId: nil,
            phoneNumbers: [],
            passkeys: [],
            passwordEnabled: false,
            twoFactorEnabled: false,
            totpEnabled: false,
            backupCodeEnabled: false,
            deleteSelfEnabled: true,
            externalAccounts: [],
            enterpriseAccounts: nil,
            publicMetadata: nil,
            unsafeMetadata: nil,
            lastSignInAt: .now,
            createdAt: .now,
            updatedAt: .now,
            createOrganizationEnabled: false,
            legalAcceptedAt: nil
        )
        
    }
    
}
