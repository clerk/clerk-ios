//
//  OAuth2IdentityProviderService.swift
//  Clerk
//
//  Created by Cursor on 11/4/25.
//

import FactoryKit
import Foundation
import Get

extension Container {

    var oauth2IdentityProviderService: Factory<OAuth2IdentityProviderService> {
        self { OAuth2IdentityProviderService() }
    }

}

/// Service for interacting with Clerk's OAuth2 Identity Provider Frontend API endpoints.
struct OAuth2IdentityProviderService {

    /// Obtain an OAuth 2.0 token for a configured Identity Provider connection.
    ///
    /// - Parameter parameters: Arbitrary token request parameters. Common keys include
    ///   `grant_type`, `connection_id` or `provider`, `scope`, `audience`, `resource`, etc.
    ///   Keys should be provided in snake_case as they will be URL-encoded as-is.
    ///
    /// - Returns: ``OAuth2TokenResponse``
    ///
    /// - Note: The request body is sent as `application/x-www-form-urlencoded` with `_is_native=true` appended
    ///   as a query parameter automatically by the API client.
    var obtainToken: @MainActor (_ parameters: [String: String]) async throws -> OAuth2TokenResponse = { parameters in
        let request = Request<OAuth2TokenResponse>.init(
            path: "/v1/oauth/token",
            method: .post,
            body: parameters
        )

        return try await Container.shared.apiClient().send(request).value
    }
}

extension Clerk {

    /// Obtain an OAuth 2.0 token from a configured OAuth2 Identity Provider connection.
    ///
    /// - Parameter parameters: Arbitrary token request parameters. Common keys include
    ///   `grant_type`, `connection_id` or `provider`, `scope`, `audience`, `resource`, etc.
    ///
    /// - Returns: ``OAuth2TokenResponse``
    ///
    /// - Example:
    /// ```swift
    /// let token = try await clerk.obtainOAuth2Token(parameters: [
    ///   "grant_type": "client_credentials",
    ///   "connection_id": "con_123",
    ///   "scope": "read:all"
    /// ])
    /// ```
    @discardableResult @MainActor
    public func obtainOAuth2Token(parameters: [String: String]) async throws -> OAuth2TokenResponse {
        try await Container.shared.oauth2IdentityProviderService().obtainToken(parameters)
    }
}
