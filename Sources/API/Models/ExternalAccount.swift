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
public struct ExternalAccount: Codable, Identifiable, Sendable {
    
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
    public let verification: Verification?
}

extension ExternalAccount: Equatable, Hashable {}

extension ExternalAccount: Comparable {
    public static func < (lhs: ExternalAccount, rhs: ExternalAccount) -> Bool {
        if lhs.verification?.status != rhs.verification?.status  {
            return lhs.verification?.status == .verified
        } else {
            return (lhs.externalProvider?.info.name ?? "") < (rhs.externalProvider?.info.name ?? "")
        }
    }
}

extension ExternalAccount {
    
    var externalProvider: ExternalProvider? {
        .init(strategy: provider)
    }
    
    /// Username if available, otherwise email address
    var displayName: String {
        if let username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        } else {
            return emailAddress
        }
    }
    
    var fullName: String? {
        let fullName = [firstName, lastName]
            .compactMap { $0 }
            .filter({ !$0.isEmpty })
            .joined(separator: " ")
        
        return fullName.isEmpty ? nil : fullName
    }
    
}

extension ExternalAccount {
    
    #if !os(tvOS) && !os(watchOS)
    /// Invokes a re-authorization flow for an existing external account.
    @MainActor
    public func reauthorize(prefersEphemeralWebBrowserSession: Bool = false) async throws {
        guard
            let redirectUrl = verification?.externalVerificationRedirectUrl,
            var url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }
        
        // if the url query doesnt contain prompt, add it
        if let query = url.query(), !query.contains("prompt") {
            url.append(queryItems: [.init(name: "prompt", value: "login")])
        }
        
        let authSession = WebAuthSession(
            url: url,
            prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
        )
        
        _ = try await authSession.start()
        
        try await Client.get()
    }
    #endif
    
    /// Deletes this external account.
    @discardableResult @MainActor
    public func destroy() async throws -> Deletion {
        let request = ClerkAPI.v1.me.externalAccounts.id(id).delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
}
