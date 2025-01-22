//
//  IDTokenProvider.swift
//
//
//  Created by Mike Pitre on 9/16/24.
//

import Foundation

/// Represents the available identity providers for ID token authentication.
public enum IDTokenProvider {
    /// The identity provider for Sign in with Apple.
    case apple
    
    /// Returns the corresponding strategy string for the identity provider.
    var strategy: String {
        switch self {
        case .apple:
            return "oauth_token_apple"
        }
    }
}
