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
public struct SignUp: Codable {
    
    let id: String
    
    /**
     The status of the current sign-up.
     
     The following values are supported:
     - `missing_requirements`: There are required fields that are either missing or they are unverified.
     - `complete`: All the required fields have been supplied and verified, so the sign-up is complete and a new user and a session have been created.
     - `abandoned`: The sign-up has been inactive for a long period of time, thus it's considered as abandoned and need to start over.
     */
    public let status: Status?
    
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
    
    ///
    public let passwordEnabled: Bool
    
    /// The first name supplied to the current sign-up. This attribute is available only if name is enabled in personal information. Check the available for more information. lastName
    public let firstName: String?
    
    /// The last name supplied to the current sign-up. This attribute is available only if name is enabled in personal information. Check the available instance settings for more information.
    public let lastName: String?
    
    /// Metadata that can be read and set from the frontend. Once the sign-up is complete, the value of this field will be automatically copied to the newly created user's unsafe metadata. One common use case for this attribute is to use it to implement custom fields that can be collected during sign-up and will automatically be attached to the created User object.
    public let unsafeMetadata: JSON?
    
    ///
    public let publicMetadata: JSON?
    
    ///
    public let customAction: Bool
    
    ///
    public let externalId: String?
    
    /// The identifier of the newly-created session. This attribute is populated only when the sign-up is complete.
    public let createdSessionId: String?
    
    /// The identifier of the newly-created user. This attribute is populated only when the sign-up is complete.
    public  let createdUserId: String?
    
    /// The date when the sign-up was abandoned by the user.
    public let abandonAt: Date
    
    /// The status of the current sign-up.
    public enum Status: String, Codable {
        /// The sign-up has been inactive for a long period of time, thus it's considered as abandoned and needs to start over.
        case abandoned
        /// There are required fields that are either missing or they are unverified.
        case missingRequirements = "missing_requirements"
        /// All the required fields have been supplied and verified, so the sign-up is complete and a new user and a session have been created..
        case complete
    }
    
    public init(
        id: String = "",
        status: SignUp.Status? = nil,
        requiredFields: [String] = [],
        optionalFields: [String] = [],
        missingFields: [String] = [],
        unverifiedFields: [String] = [],
        verifications: [String: Verification] = [:],
        username: String? = nil,
        emailAddress: String? = nil,
        phoneNumber: String? = nil,
        web3Wallet: String? = nil,
        passwordEnabled: Bool = false,
        firstName: String? = nil,
        lastName: String? = nil,
        unsafeMetadata: JSON? = nil,
        publicMetadata: JSON? = nil,
        customAction: Bool = false,
        externalId: String? = nil,
        createdSessionId: String? = nil,
        createdUserId: String? = nil,
        abandonAt: Date = .now
    ) {
        self.id = id
        self.status = status
        self.requiredFields = requiredFields
        self.optionalFields = optionalFields
        self.missingFields = missingFields
        self.unverifiedFields = unverifiedFields
        self.verifications = verifications
        self.username = username
        self.emailAddress = emailAddress
        self.phoneNumber = phoneNumber
        self.web3Wallet = web3Wallet
        self.passwordEnabled = passwordEnabled
        self.firstName = firstName
        self.lastName = lastName
        self.unsafeMetadata = unsafeMetadata
        self.publicMetadata = publicMetadata
        self.customAction = customAction
        self.externalId = externalId
        self.createdSessionId = createdSessionId
        self.createdUserId = createdUserId
        self.abandonAt = abandonAt
    }
    
    /**
     This method initiates a new sign-up flow. It creates a new `SignUp` object and de-activates any existing `SignUp` that the client might already had in progress.
     
     The form of the given `params` depends on the configuration of the instance. Choices on the instance settings affect which options are available to use.
     
     The `create` method will return a promise of the new `SignUp` object. This sign up might be complete if you supply the required fields in one go.
     However, this is not mandatory. Our sign-up process provides great flexibility and allows users to easily create multi-step sign-up flows.
     */
    @MainActor
    public func create(_ strategy: CreateStrategy) async throws {
        let params = createParams(for: strategy)
        let request = ClerkAPI.v1.client.signUps.post(params)
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    public enum CreateStrategy {
        case standard(emailAddress: String? = nil, password: String? = nil, firstName: String? = nil, lastName: String? = nil, username: String? = nil, phoneNumber: String? = nil)
        case externalProvider(_ provider: ExternalProvider)
        case transfer
    }
    
    private func createParams(for strategy: CreateStrategy) -> CreateParams {
        switch strategy {
        case .standard(let emailAddress, let password, let firstName, let lastName, let username,  let phoneNumber):
            return .init(firstName: firstName, lastName: lastName, password: password, emailAddress: emailAddress, phoneNumber: phoneNumber, username: username)
        case .externalProvider(let provider):
            return .init(strategy: .externalProvider(provider), redirectUrl: "clerk://", actionCompleteRedirectUrl: "clerk://")
        case .transfer:
            return .init(transfer: true)
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
            transfer: Bool? = nil
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
    }
    
    /**
     The prepareVerification is used to initiate the verification process for a field that requires it.
     
     As mentioned above, there are two fields that need to be verified:
     - emailAddress: The email address can be verified via an email code. This is a one-time code that is sent to the email already provided to the SignUp object. The prepareVerification sends this email.
     - phoneNumber: The phone number can be verified via a phone code. This is a one-time code that is sent via an SMS to the phone already provided to the SignUp object. The prepareVerification sends this SMS.
     */
    @MainActor
    public func prepareVerification(_ strategy: PrepareStrategy) async throws {
        let params = prepareParams(for: strategy)
        let request = ClerkAPI.v1.client.signUps.id(id).prepareVerification.post(params)
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
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
    @MainActor
    public func attemptVerification(_ strategy: AttemptStrategy) async throws {
        let params = attemptParams(for: strategy)
        let request = ClerkAPI.v1.client.signUps.id(id).attemptVerification.post(params)
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
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
    
    public func startExternalAuth() async throws {
        guard
            let verification = verifications.first(where: { $0.key == "external_account" })?.value,
            let redirectUrl = verification.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL not provided. Unable to start external flow.")
        }
        
        let authSession = ExternalAuthWebSession(url: url, authAction: .signUp)
        try await authSession.start()
    }
    
    @MainActor
    public func get(rotatingTokenNonce: String? = nil) async throws {
        let request = ClerkAPI.v1.client.signUps.id(id).get(rotatingTokenNonce: rotatingTokenNonce)
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
}

extension SignUp {
    
    /// Returns the next attribute that needs to verified at sign up
    var nextStrategyToVerify: Strategy? {
        let attributesToVerify = Clerk.shared.environment.userSettings.attributesToVerifyAtSignUp
        
        if unverifiedFields.contains(where: { $0 == "email_address" }) {
            guard let emailVerifications = attributesToVerify.first(where: { $0.key == .emailAddress })?.value.verificationStrategies else {
                return nil
            }
            
            if emailVerifications.contains(where: { $0 == .emailCode }) {
                return .emailCode
            } else {
                return nil
            }
            
        } else if unverifiedFields.contains(where: { $0 == "phone_number" }) {
            return attributesToVerify.first(where: { $0.key == .phoneNumber })?.value.verificationStrategies.first
            
        } else {
            return nil
        }
    }
    
}
