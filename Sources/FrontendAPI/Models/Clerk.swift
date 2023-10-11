//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Factory

/**
 This is the main entrypoint class for the clerk-ios package. It contains a number of methods and properties for interacting with the Clerk API.
 
 Holds a `.shared` instance.
 */
final public class Clerk: ObservableObject {
    
    /// The shared clerk instance
    public static let shared = Container.shared.clerk()
    
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
    private(set) public var publishableKey: String = ""
    
    /// Frontend API URL
    private(set) public var frontendAPIURL: String = ""
    
    /// The Client object for the current device.
    @Published internal(set) public var client: Client = .init()
    
    /// The Environment for the clerk instance.
    @Published internal(set) public var environment: Clerk.Environment = .init()
    
    /// Is the sign in flow being displayed.
    @Published public var signInIsPresented = false
}

extension Container {
    
    var clerk: Factory<Clerk> {
        self { Clerk() }
            .singleton
    }
    
}

#if DEBUG
extension Clerk {
    public static var mock: Clerk {
        let clerk = Clerk()
        
        let userData = UserData(
            firstName: "First",
            lastName: "Last",
            imageUrl: "",
            hasImage: true
        )
        
        let signInFactor = SignInFactor(
            strategy: .emailCode,
            safeIdentifier: "clerkUser@gmail.com",
            emailAddressId: "123"
        )
        
        let signIn = SignIn(
            id: "123",
            status: "",
            supportedFirstFactors: [signInFactor],
            userData: userData
        )
        
        let client = Client(
            signIn: signIn,
            signUp: SignUp(),
            sessions: []
        )
        
        clerk.client = client
        
        return clerk
    }
}
#endif

