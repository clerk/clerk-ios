//
//  File.swift
//  
//
//  Created by Mike Pitre on 3/19/24.
//

import Foundation

extension Clerk {
    
    public struct OAuthSettings {
        /// - Parameter redirectUrl: The URL to redirect back to one the OAuth flow has completed successfully or unsuccessfully.By default, this is set to `{YOUR_APPS_BUNDLE_IDENTIFIER}://oauth_callback`.
        /// - Parameter callbackUrlScheme: The custom URL scheme that the app expects in the callback URL. By default, this is set to your app's bundle identifier.

        public init(
            redirectUrl: String = "\(Bundle.main.bundleIdentifier ?? "")://oauth_callback",
            callbackUrlScheme: String = Bundle.main.bundleIdentifier ?? ""
        ) {
            self.redirectUrl = redirectUrl
            self.callbackUrlScheme = callbackUrlScheme
        }
        
        /// The URL to redirect back to one the OAuth flow has completed successfully or unsuccessfully.
        public var redirectUrl: String
        /// The custom URL scheme that the app expects in the callback URL.
        public var callbackUrlScheme: String
    }
    
}
