//
//  RedirectConfig.swift
//
//
//  Created by Mike Pitre on 3/19/24.
//

import Foundation

/// A configuration object that can be passed to `Clerk.configure()` to customize redirect behavior for OAuth flows and deep linking.
public struct RedirectConfig: Sendable {

    /// The URL that OAuth providers should redirect to after authentication. Defaults to "{bundleIdentifier}://callback".
    public let redirectUrl: String

    /// The URL scheme used for handling callbacks from OAuth providers. Defaults to the bundle identifier.
    public let callbackUrlScheme: String

    /// Initializes a ``RedirectConfig`` instance.
    /// - Parameters:
    ///   - redirectUrl: The URL that OAuth providers should redirect to after authentication. Defaults to "{bundleIdentifier}://callback".
    ///   - callbackUrlScheme: The URL scheme used for handling callbacks from OAuth providers. Defaults to the bundle identifier.
    public init(
        redirectUrl: String = "\(Bundle.main.bundleIdentifier ?? "")://callback",
        callbackUrlScheme: String = Bundle.main.bundleIdentifier ?? ""
    ) {
        self.redirectUrl = redirectUrl
        self.callbackUrlScheme = callbackUrlScheme
    }
}
