//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Factory
import RegexBuilder

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
     
     - Note:
     It's essential to call this function with the appropriate values before using any other package functionality. 
     Failure to configure the package may result in unexpected behavior or errors.
     
     Example Usage:
     ```swift
     Clerk.shared.configure(publishableKey: "pk_your_publishable_key")
     */
    public func configure(publishableKey: String) {
        self.publishableKey = publishableKey
    }
    
    /// Publishable Key: Formatted as pk_test_ in development and pk_live_ in production.
    private(set) public var publishableKey: String = "" {
        didSet {
            let liveRegex = Regex {
                "pk_live_"
                Capture {
                    OneOrMore(.any)
                }
                "k"
            }
            
            let testRegex = Regex {
                "pk_test_"
                Capture {
                    OneOrMore(.any)
                }
                "k"
            }
            
            if
                let match = publishableKey.firstMatch(of: liveRegex)?.output.1 ?? publishableKey.firstMatch(of: testRegex)?.output.1,
                let apiUrl = String(match).base64Decoded()
            {
                frontendAPIURL = "https://\(apiUrl)"
            }
        }
    }
    
    /// Frontend API URL
    private(set) public var frontendAPIURL: String = ""
    
    /// The Client object for the current device.
    @Published internal(set) public var client: Client = .init()
    
    /// The Environment for the clerk instance.
    @Published internal(set) public var environment: Clerk.Environment = .init()
}

extension Container {
    
    public var clerk: Factory<Clerk> {
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
        
        let factor = Factor(
            strategy: .emailCode,
            safeIdentifier: "ClerkUser@clerk.dev", 
            emailAddressId: "123",
            phoneNumberId: nil,
            web3WalletId: nil,
            primary: true,
            default: nil
        )
        
        let firstFactorVerification = Verification(
            status: .unverified,
            strategy: .emailCode,
            attempts: 0,
            expireAt: .distantFuture, 
            error: nil
        )
        
        let signIn = SignIn(
            id: "123",
            status: .needsFirstFactor,
            supportedFirstFactors: [factor],
            firstFactorVerification: firstFactorVerification,
            identifier: "ClerkUser@clerk.dev",
            userData: userData
        )
        
        let signUp = SignUp(
            unverifiedFields: [
                "email_address",
                "phone_number"
            ], 
            emailAddress: "ClerkUser@clerk.dev",
            phoneNumber: "+12015550123"
        )
                
        let emailAddresses = [
            EmailAddress(
                id: "123",
                emailAddress: "ClerkUser@clerk.dev",
                reserved: false,
                verification: .init(),
                linkedTo: nil
            )
        ]
        
        let phoneNumbers = [
            PhoneNumber(
                id: "123",
                phoneNumber: "+12015550123",
                reservedForSecondFactor: false,
                defaultSecondFactor: false,
                verification: .init(),
                linkedTo: nil,
                backupCodes: nil
            )
        ]
        
        let user = User(
            firstName: "Clerk", 
            lastName: "User",
            imageUrl: "image",
            primaryEmailAddressId: "123",
            primaryPhoneNumberId: "123",
            emailAddresses: emailAddresses,
            phoneNumbers: phoneNumbers
        )
        
        let session = Session(
            id: "123",
            user: user,
            status: "active"
        )
        
        let client = Client(
            signIn: signIn,
            signUp: signUp,
            sessions: [session],
            lastActiveSessionId: "123"
        )
        
        let userSettings = Environment.UserSettings(
            attributes: [
                "phone_number": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: true,
                    firstFactors: [],
                    usedForSecondFactor: false,
                    secondFactors: [],
                    verifications: ["phone_code"],
                    verifyAtSignUp: true
                ),
                "email_address": .init(
                    enabled: true,
                    required: false,
                    usedForFirstFactor: true,
                    firstFactors: [],
                    usedForSecondFactor: false,
                    secondFactors: [],
                    verifications: ["email_code"],
                    verifyAtSignUp: true
                )
            ],
            social: [
                "oauth_apple": .init(
                    enabled: true,
                    required: false,
                    authenticatable: true,
                    strategy: "oauth_apple",
                    notSelectable: false
                ),
                "oauth_google": .init(
                    enabled: true,
                    required: false,
                    authenticatable: true,
                    strategy: "oauth_google",
                    notSelectable: false
                )
            ]
        )
        
        let displayConfig = Environment.DisplayConfig(
            applicationName: "Clerk"
        )
        
        clerk.environment.userSettings = userSettings
        clerk.environment.displayConfig = displayConfig
        clerk.client = client
        
        return clerk
    }
}
#endif

