//
//  RedirectConfig.swift
//
//
//  Created by Mike Pitre on 3/19/24.
//

import Foundation

/// The configurable redirect settings. For example: `redirectUrl`, `callbackUrlScheme`
public struct RedirectConfig {
    
    /// - Parameter redirectUrl: The URL to redirect back to once an external flow has completed successfully or unsuccessfully. By default, this is set to `{YOUR_APPS_BUNDLE_IDENTIFIER}://callback`.
    /// - Parameter callbackUrlScheme: The custom URL scheme that the app expects in the callback URL. By default, this is set to your app's bundle identifier.
    public init(
        redirectUrl: String = "\(Bundle.main.bundleIdentifier ?? "")://callback",
        callbackUrlScheme: String = Bundle.main.bundleIdentifier ?? ""
    ) {
        self.redirectUrl = redirectUrl
        self.callbackUrlScheme = callbackUrlScheme
    }
    
    /// The URL to redirect back to once the external flow has completed successfully or unsuccessfully.
    public var redirectUrl: String
    
    /// The custom URL scheme that the app expects in the callback URL.
    public var callbackUrlScheme: String
}
