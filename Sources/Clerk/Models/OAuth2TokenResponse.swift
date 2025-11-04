//
//  OAuth2TokenResponse.swift
//  Clerk
//
//  Created by Cursor on 11/4/25.
//

import Foundation

/// Standard OAuth 2.0 token response returned from Clerk's OAuth2 Identity Provider endpoint.
///
/// This structure models the most common fields defined by RFC 6749 and
/// is intentionally general so it can be used with any configured OAuth2
/// Identity Provider connection in Clerk.
public struct OAuth2TokenResponse: Codable, Equatable, Sendable {

    /// The access token issued by the authorization server.
    public let accessToken: String

    /// The type of the token issued.
    public let tokenType: String

    /// The lifetime in seconds of the access token.
    public let expiresIn: Int?

    /// A refresh token used to obtain a new access token (if issued).
    public let refreshToken: String?

    /// The scope of the access token (if different from the requested one).
    public let scope: String?

    /// If the provider returns an ID token (OIDC), it will be included here.
    public let idToken: String?

    public init(
        accessToken: String,
        tokenType: String,
        expiresIn: Int? = nil,
        refreshToken: String? = nil,
        scope: String? = nil,
        idToken: String? = nil
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.scope = scope
        self.idToken = idToken
    }
}

extension OAuth2TokenResponse {
    static var mock: OAuth2TokenResponse {
        .init(accessToken: "access_token", tokenType: "Bearer", expiresIn: 3600, refreshToken: "refresh_token", scope: "read:all", idToken: "id_token")
    }
}
