//
//  ExternalAccount.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation

/**
 The ExternalAccount object is a model around an identification obtained by an external provider (e.g. an OAuth provider such as Google).

 External account must be verified, so that you can make sure they can be assigned to their rightful owners. The ExternalAccount object holds all necessary state around the verification process.
 */
public struct ExternalAccount: Codable, Identifiable {
    
    /// A unique identifier for this external account.
    public let id: String
    
    /// The provider name e.g. google
    let provider: String
    
    /// The identification with which this external account is associated.
    let identificationId: String
    
    /// The unique ID of the user in the provider.
    let providerUserId: String
    
    /// The scopes that the user has granted access to.
    let approvedScopes: String
    
    /// The provided email address of the user.
    public let emailAddress: String
    
    /// The provided first name of the user.
    let firstName: String?
    
    /// The provided last name of the user.
    let lastName: String?
        
    /// The provided image URL of the user.
    public let imageUrl: String?
    
    /// The provided username of the user.
    let username: String?
    
    /// Metadata provided about the user from the provider.
    let publicMetadata: JSON
    
    /// A descriptive label to differentiate multiple external accounts of the same user for the same provider.
    let label: String?
    
    /// An object holding information on the verification of this external account.
    public let verification: Verification
}

extension ExternalAccount: Equatable, Hashable {}

extension ExternalAccount: Comparable {
    public static func < (lhs: ExternalAccount, rhs: ExternalAccount) -> Bool {
        if lhs.verification.status != rhs.verification.status  {
            return lhs.verification.status == .verified
        } else {
            return (lhs.externalProvider?.data.name ?? "") < (rhs.externalProvider?.data.name ?? "")
        }
    }
}

extension ExternalAccount {
    
    public var externalProvider: OAuthProvider? {
        .init(strategy: provider)
    }
    
    /// Username if available, otherwise email address
    public var displayName: String {
        username ?? emailAddress
    }
    
    public var fullName: String? {
        let fullName = [firstName, lastName]
            .compactMap { $0 }
            .filter({ !$0.isEmpty })
            .joined(separator: " ")
        
        return fullName.isEmpty ? nil : fullName
    }
    
}

extension ExternalAccount {
    
    struct CreateParams: Encodable {
        init(
            oauthProvider: OAuthProvider,
            redirectUrl: String,
            additionalScopes: [String]? = nil
        ) {
            self.strategy = oauthProvider.data.strategy
            self.redirectUrl = redirectUrl
            self.additionalScopes = additionalScopes
        }
        
        let strategy: String
        let redirectUrl: String
        let additionalScopes: [String]?
    }
    
}

extension ExternalAccount {
    
    @MainActor
    public func delete() async throws {
        let request = APIEndpoint
            .v1
            .me
            .externalAccounts
            .id(id)
            .delete
        
        try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }
        try await Clerk.shared.client.get()
    }
    
}
