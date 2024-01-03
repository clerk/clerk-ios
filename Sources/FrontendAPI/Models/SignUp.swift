//
//  SignUp.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/**
 The SignUp object holds the state of the current sign up and provides helper methods to navigate and complete the sign up flow. Once a sign up is complete, a new user is created.
 
 There are two important steps that need to be done in order for a sign up to be completed:
 
 Supply all the required fields. The required fields depend on your instance settings.
 Verify contact information. Some of the supplied fields need extra verification. These are the email address and phone number.
 The above steps can be split into smaller actions (e.g. you don't have to supply all the required fields at once) and can done in any order. This provides great flexibility and supports even the most complicated sign up flows.
 
 Also, the attributes of the SignUp object can basically be grouped into three categories:
 
 Those that contain information regarding the sign-up flow and what is missing in order for the sign-up to complete. For more information on these, check our detailed sign-up flow guide.
 Those that hold the different values that we supply to the sign-up. Examples of these are username, emailAddress, firstName, etc.
 Those that contain references to the created resources once the sign-up is complete, i.e. createdSessionId and createdUserId.
 */
public class SignUp: Codable {
    
    public init(
        id: String = "",
        status: SignUp.Status? = nil,
        requiredFields: [String] = [],
        optionalFields: [String] = [],
        missingFields: [String] = [],
        unverifiedFields: [String] = [],
        verifications: [String: SignUpVerification] = [:],
        username: String? = nil,
        emailAddress: String? = nil,
        phoneNumber: String? = nil, 
        web3Wallet: String? = nil,
        passwordEnabled: Bool = false,
        firstName: String? = nil,
        lastName: String? = nil,
        unsafeMetadata: JSON = nil,
        publicMetadata: JSON = nil,
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
    
    let id: String
    
    /**
     The status of the current sign-up.
     
     The following values are supported:
     - missing_requirements: There are required fields that are either missing or they are unverified.
     - complete: All the required fields have been supplied and verified, so the sign-up is complete and a new user and a session have been created.
     - abandoned: The sign-up has been inactive for a long period of time, thus it's considered as abandoned and need to start over.
     */
    public let status: Status?
    
    public enum Status: String, Codable {
        case missingRequirements = "missing_requirements"
        case complete
        case abandoned
    }
    
    /// An array of all the required fields that need to be supplied and verified in order for this sign-up to be marked as complete and converted into a user.
    let requiredFields: [String]
    
    /// An array of all the fields that can be supplied to the sign-up, but their absence does not prevent the sign-up from being marked as complete.
    let optionalFields: [String]
    
    /// An array of all the fields whose values are not supplied yet but they are mandatory in order for a sign-up to be marked as complete.
    let missingFields: [String]
    
    /// An array of all the fields whose values have been supplied, but they need additional verification in order for them to be accepted. Examples of such fields are emailAddress and phoneNumber.
    public let unverifiedFields: [String]
    
    /// An object that contains information about all the verifications that are in-flight.
    public let verifications: [String: SignUpVerification?]
    
    /// The username supplied to the current sign-up. This attribute is available only if usernames are enabled. Check the available instance settings in your Clerk Dashboard for more information.
    let username: String?
    
    /// The email address supplied to the current sign-up. This attribute is available only if the selected contact information includes email address. Check the available instance settings for more information.
    public let emailAddress: String?
    
    /// The phone number supplied to the current sign-up. This attribute is available only if the selected contact information includes phone number. Check the available instance settings for more information.
    public let phoneNumber: String?
    
    /// The Web3 wallet public address supplied to the current sign-up. In Ethereum, the address is made up of 0x + 40 hexadecimal characters.
    let web3Wallet: String?
    
    ///
    let passwordEnabled: Bool
    
    /// The first name supplied to the current sign-up. This attribute is available only if name is enabled in personal information. Check the available for more information. lastName
    let firstName: String?
    
    /// The last name supplied to the current sign-up. This attribute is available only if name is enabled in personal information. Check the available instance settings for more information.
    let lastName: String?
    
    /// Metadata that can be read and set from the frontend. Once the sign-up is complete, the value of this field will be automatically copied to the newly created user's unsafe metadata. One common use case for this attribute is to use it to implement custom fields that can be collected during sign-up and will automatically be attached to the created User object.
    let unsafeMetadata: JSON?
    
    ///
    let publicMetadata: JSON?
    
    ///
    let customAction: Bool
    
    ///
    let externalId: String?
    
    /// The identifier of the newly-created session. This attribute is populated only when the sign-up is complete.
    let createdSessionId: String?
    
    /// The identifier of the newly-created user. This attribute is populated only when the sign-up is complete.
    let createdUserId: String?
    
    /// The epoch numerical time when the sign-up was abandoned by the user.
    let abandonAt: Date
}

extension SignUp {
    
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
        
        public var firstName: String?
        public var lastName: String?
        public var password: String?
        public var emailAddress: String?
        public var phoneNumber: String?
        public var username: String?
        public var strategy: String?
        public var redirectUrl: String?
        public var actionCompleteRedirectUrl: String?
        public var transfer: Bool?
    }
    
    public struct PrepareVerificationParams: Encodable {
        public init(strategy: Strategy) {
            self.strategy = strategy.stringValue
        }
        
        public var strategy: String
    }
    
    public struct AttemptVerificationParams: Encodable {
        public init(
            strategy: Strategy,
            code: String
        ) {
            self.strategy = strategy.stringValue
            self.code = code
        }
        
        public var strategy: String
        public var code: String
    }
    
    public struct GetParams: Encodable {
        public init(rotatingTokenNonce: String? = nil) {
            self.rotatingTokenNonce = rotatingTokenNonce
        }
        
        public var rotatingTokenNonce: String?
    }
    
}

extension SignUp {
    
    public enum CreateStrategy {
        case standard(emailAddress: String? = nil, password: String? = nil, firstName: String? = nil, lastName: String? = nil, username: String? = nil, phoneNumber: String? = nil)
        case oauth(provider: OAuthProvider)
        case transfer
    }
    
    private func createParams(for strategy: CreateStrategy) -> CreateParams {
        switch strategy {
        case .standard(let emailAddress, let password, let firstName, let lastName, let username,  let phoneNumber):
            return .init(firstName: firstName, lastName: lastName, password: password, emailAddress: emailAddress, phoneNumber: phoneNumber, username: username)
        case .oauth(let provider):
            return .init(strategy: .oauth(provider), redirectUrl: "clerk://", actionCompleteRedirectUrl: "clerk://")
        case .transfer:
            return .init(transfer: true)
        }
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
    
}

extension SignUp {
    
    /// Returns the next attribute that needs to verified at sign up
    public var nextStrategyToVerify: Strategy? {
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

extension SignUp {
    
    /**
     This method initiates a new sign-up flow. It creates a new SignUp object and de-activates any existing SignUp that the client might already had in progress.
     
     The form of the given params depends on the configuration of the instance. Choices on the instance settings affect which options are available to use.
     
     The create method will return a promise of the new SignUp object. This sign up might be complete if you supply the required fields in one go.
     However, this is not mandatory. Our sign-up process provides great flexibility and allows users to easily create multi-step sign-up flows.
     */
    @MainActor
    public func create(_ strategy: CreateStrategy) async throws {
        let params = createParams(for: strategy)
        let request = APIEndpoint
            .v1
            .client
            .signUps
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
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
        let request = APIEndpoint
            .v1
            .client
            .signUps
            .id(id)
            .prepareVerification
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    /**
     Attempts to complete the in-flight verification process that corresponds to the given strategy. In order to use this method, you should first initiate a verification process by calling SignUp.prepareVerification.
     
     Depending on the strategy, the method parameters could differ.
     */
    @MainActor
    public func attemptVerification(_ strategy: AttemptStrategy) async throws {
        let params = attemptParams(for: strategy)
        let request = APIEndpoint
            .v1
            .client
            .signUps
            .id(id)
            .attemptVerification
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    @MainActor
    public func get(_ params: GetParams? = nil) async throws {
        let request = APIEndpoint
            .v1
            .client
            .signUps
            .id(id)
            .get(params: params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
}
