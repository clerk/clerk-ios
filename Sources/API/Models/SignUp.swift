//
//  SignUp.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/**
 The `SignUp` object holds the state of the current sign up and provides helper methods to navigate and complete the sign up flow. Once a sign up is complete, a new user is created.
 
 There are two important steps that need to be done in order for a sign up to be completed:
 
 - Supply all the required fields. The required fields depend on your instance settings.
 - Verify contact information. Some of the supplied fields need extra verification. These are the email address and phone number.
 
 The above steps can be split into smaller actions (e.g. you don't have to supply all the required fields at once) and can done in any order. This provides great flexibility and supports even the most complicated sign up flows.
 
 Also, the attributes of the `SignUp` object can basically be grouped into three categories:
 
 - Those that contain information regarding the sign-up flow and what is missing in order for the sign-up to complete. For more information on these, check our detailed sign-up flow guide.
 - Those that hold the different values that we supply to the sign-up. Examples of these are `username`, `emailAddress`, `firstName`, etc.
 - Those that contain references to the created resources once the sign-up is complete, i.e. `createdSessionId` and `createdUserId`.
 */
public struct SignUp: Codable, Sendable, Equatable {
    
    let id: String
    
    /**
     The status of the current sign-up.
     
     The following values are supported:
     - `missing_requirements`: There are required fields that are either missing or they are unverified.
     - `complete`: All the required fields have been supplied and verified, so the sign-up is complete and a new user and a session have been created.
     - `abandoned`: The sign-up has been inactive for a long period of time, thus it's considered as abandoned and need to start over.
     */
    public let status: Status
    
    /// An array of all the required fields that need to be supplied and verified in order for this sign-up to be marked as complete and converted into a user.
    public let requiredFields: [String]
    
    /// An array of all the fields that can be supplied to the sign-up, but their absence does not prevent the sign-up from being marked as complete.
    public let optionalFields: [String]
    
    /// An array of all the fields whose values are not supplied yet but they are mandatory in order for a sign-up to be marked as complete.
    public let missingFields: [String]
    
    /// An array of all the fields whose values have been supplied, but they need additional verification in order for them to be accepted. Examples of such fields are emailAddress and phoneNumber.
    public let unverifiedFields: [String]
    
    /// An object that contains information about all the verifications that are in-flight.
    public let verifications: [String: Verification?]
    
    /// The username supplied to the current sign-up. This attribute is available only if usernames are enabled. Check the available instance settings in your Clerk Dashboard for more information.
    public let username: String?
    
    /// The email address supplied to the current sign-up. This attribute is available only if the selected contact information includes email address. Check the available instance settings for more information.
    public let emailAddress: String?
    
    /// The phone number supplied to the current sign-up. This attribute is available only if the selected contact information includes phone number. Check the available instance settings for more information.
    public let phoneNumber: String?
    
    /// The Web3 wallet public address supplied to the current sign-up. In Ethereum, the address is made up of 0x + 40 hexadecimal characters.
    public let web3Wallet: String?
    
    /// The value of this attribute is true if a password was supplied to the current sign-up. This attribute is available only if password-based authentication is enabled. Check the available instance settings for more information.
    public let passwordEnabled: Bool
    
    /// The first name supplied to the current sign-up. This attribute is available only if name is enabled in personal information. Check the available for more information. lastName
    public let firstName: String?
    
    /// The last name supplied to the current sign-up. This attribute is available only if name is enabled in personal information. Check the available instance settings for more information.
    public let lastName: String?
    
    /// Metadata that can be read and set from the frontend. Once the sign-up is complete, the value of this field will be automatically copied to the newly created user's unsafe metadata. One common use case for this attribute is to use it to implement custom fields that can be collected during sign-up and will automatically be attached to the created User object.
    public let unsafeMetadata: JSON?
    
    ///
    let publicMetadata: JSON?
    
    ///
    let customAction: Bool
    
    ///
    let externalId: String?
    
    /// The identifier of the newly-created session. This attribute is populated only when the sign-up is complete.
    public let createdSessionId: String?
    
    /// The identifier of the newly-created user. This attribute is populated only when the sign-up is complete.
    public  let createdUserId: String?
    
    /// The date when the sign-up was abandoned by the user.
    public let abandonAt: Date
    
    /// The status of the current sign-up.
    public enum Status: String, Codable, Sendable, Equatable {
        /// The sign-up has been inactive for a long period of time, thus it's considered as abandoned and needs to start over.
        case abandoned
        /// There are required fields that are either missing or they are unverified.
        case missingRequirements = "missing_requirements"
        /// All the required fields have been supplied and verified, so the sign-up is complete and a new user and a session have been created..
        case complete
    }
    
    /**
     This method initiates a new sign-up flow. It creates a new `SignUp` object and de-activates any existing `SignUp` that the client might already had in progress.
     
     Choices on the instance settings affect which options are available to use.
     
     This sign up might be complete if you supply the required fields in one go.
     However, this is not mandatory. Our sign-up process provides great flexibility and allows users to easily create multi-step sign-up flows.
     */
    @discardableResult @MainActor
    public static func create(strategy: SignUp.CreateStrategy, captchaToken: String? = nil) async throws -> SignUp {
        let params = SignUp.createParams(for: strategy, captchaToken: captchaToken)
        let request = ClerkAPI.v1.client.signUps.post(params)
        let response = try await Clerk.shared.apiClient.send(request).value.response
        try await Clerk.shared.client?.get()
        return response
    }
    
    public enum CreateStrategy {
        case standard(emailAddress: String? = nil, password: String? = nil, firstName: String? = nil, lastName: String? = nil, username: String? = nil, phoneNumber: String? = nil)
        case externalProvider(_ provider: ExternalProvider)
        case transfer
    }
    
    static func createParams(for strategy: CreateStrategy, captchaToken: String? = nil) -> CreateParams {
        switch strategy {
        case .standard(let emailAddress, let password, let firstName, let lastName, let username,  let phoneNumber):
            return .init(firstName: firstName, lastName: lastName, password: password, emailAddress: emailAddress, phoneNumber: phoneNumber, username: username, captchaToken: captchaToken)
        case .externalProvider(let provider):
            return .init(strategy: .externalProvider(provider), redirectUrl: Clerk.shared.redirectConfig.redirectUrl, actionCompleteRedirectUrl: Clerk.shared.redirectConfig.redirectUrl, captchaToken: captchaToken)
        case .transfer:
            return .init(transfer: true, captchaToken: captchaToken)
        }
    }
    
    public struct CreateParams: Encodable {
        public init(
            firstName: String? = nil,
            lastName: String? = nil,
            password: String? = nil,
            emailAddress: String? = nil,
            phoneNumber: String? = nil,
            username: String? = nil,
            strategy: Strategy? = nil,
            redirectUrl: String? = nil,
            actionCompleteRedirectUrl: String? = nil,
            transfer: Bool? = nil,
            captchaToken: String? = nil
        ) {
            self.firstName = firstName
            self.lastName = lastName
            self.password = password
            self.emailAddress = emailAddress
            self.phoneNumber = phoneNumber
            self.username = username
            self.strategy = strategy?.stringValue
            self.redirectUrl = redirectUrl
            self.actionCompleteRedirectUrl = actionCompleteRedirectUrl
            self.transfer = transfer
            self.captchaToken = captchaToken
        }
        
        /// The user's first name. This option is available only if name is selected in personal information. Please check the instance settings for more information.
        public let firstName: String?
        
        /// The user's last name. This option is available only if name is selected in personal information. Please check the instance settings for more information.
        public let lastName: String?
        
        /// The user's password. This option is available only if password-based authentication is selected. Please check the instance settings for more information.
        public let password: String?
        
        /// The user's email address. This option is available only if email address is selected in contact information. Keep in mind that the email address requires an extra verification process. Please check the instance settings for more information.
        public let emailAddress: String?
        
        /// The user's phone number. This option is available only if phone number is selected in contact information. Keep in mind that the phone number requires an extra verification process. Please check the instance settings for more information.
        public let phoneNumber: String?
        
        /// The user's username. This option is available only if usernames are enabled. Please check the instance settings for more information.
        public let username: String?
        
        /**
         The strategy to use for the sign-up flow.
         
         The following strategies are supported:
         - `oauth_<provider>`: The user will be authenticated with their Social login account. See available OAuth Strategies.
         - `saml`: The user will be authenticated with SAML.
         - `ticket`: The user will be authenticated via the ticket or token generated from the Backend API.
         */
        public let strategy: String?
        
        /// The redirect URL after the sign-up flow has completed.
        public let redirectUrl: String?
        
        /**
         The URL that the user will be redirected to, after successful authorization from the OAuth provider and Clerk sign in.
         This parameter is required only if `strategy` is set to an OAuth strategy like `oauth_<provider>`, or set to `saml`.
         */
        public let actionCompleteRedirectUrl: String?
        
        /// Transfer the user to a dedicated sign-up for an OAuth flow.
        public let transfer: Bool?
        
        /// Optional captcha token for bot protection
        public let captchaToken: String?
    }
    
    /// This method is used to update the current sign-up.
    @discardableResult @MainActor
    public func update(params: UpdateParams) async throws -> SignUp {
        let request = ClerkAPI.v1.client.signUps.id(id).patch(params)
        let signUp = try await Clerk.shared.apiClient.send(request).value.response
        try await Clerk.shared.client?.get()
        return signUp
    }
    
    /// UpdateParams is a mirror of CreateParams with the same fields and types.
    public typealias UpdateParams = CreateParams
    
    /**
     The prepareVerification is used to initiate the verification process for a field that requires it.
     
     As mentioned above, there are two fields that need to be verified:
     - emailAddress: The email address can be verified via an email code. This is a one-time code that is sent to the email already provided to the SignUp object. The prepareVerification sends this email.
     - phoneNumber: The phone number can be verified via a phone code. This is a one-time code that is sent via an SMS to the phone already provided to the SignUp object. The prepareVerification sends this SMS.
     */
    @discardableResult @MainActor
    public func prepareVerification(_ strategy: PrepareStrategy) async throws -> SignUp {
        let params = prepareParams(for: strategy)
        let request = ClerkAPI.v1.client.signUps.id(id).prepareVerification.post(params)
        let signUp = try await Clerk.shared.apiClient.send(request).value.response
        try await Clerk.shared.client?.get()
        return signUp
    }
    
    public enum PrepareStrategy {
        case emailCode
        case phoneCode
    }
    
    private func prepareParams(for strategy: PrepareStrategy) -> PrepareVerificationParams {
        switch strategy {
        case .emailCode:
            return .init(strategy: .emailCode)
        case .phoneCode:
            return .init(strategy: .phoneCode)
        }
    }
    
    public struct PrepareVerificationParams: Encodable {
        public init(strategy: Strategy) {
            self.strategy = strategy.stringValue
        }
        
        public let strategy: String
    }
    
    /**
     Attempts to complete the in-flight verification process that corresponds to the given strategy. In order to use this method, you should first initiate a verification process by calling SignUp.prepareVerification.
     
     Depending on the strategy, the method parameters could differ.
     */
    @discardableResult @MainActor
    public func attemptVerification(_ strategy: AttemptStrategy) async throws -> SignUp {
        let params = attemptParams(for: strategy)
        let request = ClerkAPI.v1.client.signUps.id(id).attemptVerification.post(params)
        let signUp = try await Clerk.shared.apiClient.send(request).value.response
        try await Clerk.shared.client?.get()
        return signUp
    }
    
    public enum AttemptStrategy {
        case emailCode(code: String)
        case phoneCode(code: String)
    }
    
    private func attemptParams(for strategy: AttemptStrategy) -> AttemptVerificationParams {
        switch strategy {
        case .emailCode(let code):
            return .init(strategy: .emailCode, code: code)
        case .phoneCode(let code):
            return .init(strategy: .phoneCode, code: code)
        }
    }
    
    public struct AttemptVerificationParams: Encodable {
        public init(strategy: Strategy, code: String) {
            self.strategy = strategy.stringValue
            self.code = code
        }
        
        public let strategy: String
        public let code: String
    }
    
#if !os(tvOS) && !os(watchOS)
    /// Signs up users via OAuth. This is commonly known as Single Sign On (SSO), where an external account is used for verifying the user's identity.
    @discardableResult @MainActor
    public func authenticateWithRedirect(prefersEphemeralWebBrowserSession: Bool = false) async throws -> NeedsTransferToSignUp {
        guard
            let verification = verifications.first(where: { $0.key == "external_account" })?.value,
            let redirectUrl = verification.externalVerificationRedirectUrl,
            var url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }
        
        // if the url query doesnt contain prompt, add it
        if let query = url.query(), !query.contains("prompt") {
            url.append(queryItems: [.init(name: "prompt", value: "login")])
        }
        
        let authSession = ASWebAuthManager(
            url: url,
            prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
        )
        
        return try await authSession.start()
    }
#endif
    
    /// Returns the current sign up.
    @discardableResult @MainActor
    public func get(rotatingTokenNonce: String? = nil) async throws -> SignUp {
        let request = ClerkAPI.v1.client.signUps.id(id).get(rotatingTokenNonce: rotatingTokenNonce)
        let signUp = try await Clerk.shared.apiClient.send(request).value.response
        try await Clerk.shared.client?.get()
        return signUp
    }
}

extension SignUp {
    
    /// Returns the next strategy to use to verify an attribute that needs to verified at sign up
    var nextStrategyToVerify: Strategy? {
        
        if let externalVerification = verifications.first(where: { $0.value?.externalVerificationRedirectUrl != nil && $0.value?.status == .unverified }) {
            return externalVerification.value?.strategyEnum
        } else {
            guard let attributesToVerify = Clerk.shared.environment?.userSettings.attributesToVerifyAtSignUp else { return nil }

            if unverifiedFields.contains(where: { $0 == "email_address" }) {
                return attributesToVerify.first(where: { $0.key == .emailAddress })?.value.verificationStrategies.first
                
            } else if unverifiedFields.contains(where: { $0 == "phone_number" }) {
                return attributesToVerify.first(where: { $0.key == .phoneNumber })?.value.verificationStrategies.first
                
            } else {
                return nil
            }
        }
    }
    
}
