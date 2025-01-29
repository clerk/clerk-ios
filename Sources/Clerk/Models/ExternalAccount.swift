//
//  ExternalAccount.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation

///The `ExternalAccount` object is a model around an identification obtained by an external provider (e.g. a social provider such as Google).
///
///External account must be verified, so that you can make sure they can be assigned to their rightful owners. The `ExternalAccount` object holds all necessary state around the verification process.
public struct ExternalAccount: Codable, Identifiable, Sendable, Hashable, Equatable {
    
    /// The unique identifier for this external account.
    public let id: String
    
    /// The identification with which this external account is associated.
    public let identificationId: String
    
    /// The provider name e.g. google
    public let provider: String
    
    /// The unique ID of the user in the provider.
    public let providerUserId: String
    
    /// The provided email address of the user.
    public let emailAddress: String
    
    /// The scopes that the user has granted access to.
    public let approvedScopes: String
    
    /// The user's first name.
    public let firstName: String?
    
    /// The user's last name.
    public let lastName: String?
        
    /// The user's image URL.
    public let imageUrl: String?
    
    /// The user's username.
    public let username: String?
    
    /// Metadata that can be read from the Frontend API and Backend API and can be set only from the Backend API.
    public let publicMetadata: JSON
    
    /// A descriptive label to differentiate multiple external accounts of the same user for the same provider.
    public let label: String?
    
    /// An object holding information on the verification of this external account.
    public let verification: Verification?
}

extension ExternalAccount {
    
    #if !os(tvOS) && !os(watchOS)
    /// Invokes a re-authorization flow for an existing external account.
    ///
    /// - Parameters:
    ///     - prefersEphemeralWebBrowserSession: A Boolean indicating whether to prefer an ephemeral web
    ///                                         browser session (default is `false`). When `true`, the session
    ///                                         does not persist cookies or other data between sessions, ensuring
    ///                                         a private browsing experience.
    @discardableResult @MainActor
    public func reauthorize(prefersEphemeralWebBrowserSession: Bool = false) async throws -> ExternalAccount {
        guard
            let redirectUrl = verification?.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }
        
        let authSession = WebAuthentication(
            url: url,
            prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
        )
        
        _ = try await authSession.start()
        
        try await Client.get()
        guard let externalAccount = Clerk.shared.user?.externalAccounts.first(where: { $0.id == id }) else {
            throw ClerkClientError(message: "Something went wrong. Please try again.")
        }
        
        return externalAccount
    }
    #endif
    
    /// Deletes this external account.
    @discardableResult @MainActor
    public func destroy() async throws -> DeletedObject {
        let request = ClerkFAPI.v1.me.externalAccounts.id(id).delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
}
