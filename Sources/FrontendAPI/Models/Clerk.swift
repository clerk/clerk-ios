//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/**
 This is the main entrypoint class for the clerk-ios package. It contains a number of methods and properties for interacting with the Clerk API.
 
 Holds a `.shared` instance.
 */
final public class Clerk: ObservableObject {
    
    /// The shared clerk instance
    public static let shared = Clerk()
    
    /**
     Configures the settings for the Clerk package.
          
     To use the Clerk package, you'll need to copy your Publishable Key from the API Keys page in the Clerk Dashboard. 
     On this same page, click on the Advanced dropdown and copy your Frontend API URL.
     If you are signed into your Clerk Dashboard, your Publishable key should be visible.
     
     - Parameters:
     - publishableKey: Formatted as pk_test_ in development and pk_live_ in production.
     - frontendAPIURL: The URL of the frontend API.
     
     - Note:
     It's essential to call this function with the appropriate values before using any other package functionality. 
     Failure to configure the package may result in unexpected behavior or errors.
     
     Example Usage:
     ```swift
     Clerk.shared.configure(
       publishableKey: "pk_your_publishable_key",
       frontendAPIURL: "[your-domain].clerk.accounts.dev"
     )
     */
    public func configure(
        publishableKey: String,
        frontendAPIURL: String
    ) {
        self.publishableKey = publishableKey
        self.frontendAPIURL = frontendAPIURL
    }
    
    /// Publishable Key: Formatted as pk_test_ in development and pk_live_ in production.
    private(set) var publishableKey: String = ""
    
    /// Frontend API URL
    private(set) var frontendAPIURL: String = ""
    
    /// The Client object for the current device.
    @Published public var client: Client = Client()
}


