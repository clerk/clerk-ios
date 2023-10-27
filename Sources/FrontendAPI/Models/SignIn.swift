//
//  SignIn.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/**
 The SignIn object holds all the state of the current sign in and provides helper methods to navigate and complete the sign in process.

 There are two important steps in the sign in flow.

 Users must complete a first factor verification. This can be something like providing a password, an email magic link, a one-time code (OTP), a web3 wallet public address or providing proof of their identity through an external social account (SSO/OAuth).
 After that, users might need to go through a second verification process. This is the second factor (2FA).
 The SignIn object's properties can be split into logical groups, with each group providing information on different aspects of the sign in flow. These groups can be:

 Information about the current sign in status in general and which authentication identifiers, authentication methods and verifications are supported.
 Information about the user and the provided authentication identifier value (email address, phone number or username). Information about each verification, either the first factor (logging in) or the second factor (2FA).
 */
public class SignIn: Decodable {
    public init(
        id: String = "",
        status: SignIn.Status? = nil,
        supportedIdentifiers: [String] = [],
        supportedFirstFactors: [SignInFactor] = [],
        supportedSecondFactors: [String]? = nil,
        firstFactorVerification: Verification? = nil,
        secondFactorVerification: Verification? = nil,
        identifier: String? = nil,
        userData: UserData? = nil,
        createdSessionId: String? = nil,
        abandonAt: Date = .now
    ) {
        self.id = id
        self.status = status
        self.supportedIdentifiers = supportedIdentifiers
        self.supportedFirstFactors = supportedFirstFactors
        self.supportedSecondFactors = supportedSecondFactors
        self.firstFactorVerification = firstFactorVerification
        self.secondFactorVerification = secondFactorVerification
        self.identifier = identifier
        self.userData = userData
        self.createdSessionId = createdSessionId
        self.abandonAt = abandonAt
    }
    
    let id: String
    
    /**
     The current status of the sign-in.
     
     The following values are supported:
     - needs_identifier: The authentication identifier hasn't been provided.
     - needs_first_factor: First factor verification for the provided identifier needs to be prepared and verified.
     - needs_second_factor: Second factor verification (2FA) for the provided identifier needs to be prepared and verified.
     - complete: The sign-in is complete and the user is authenticated.
     - abandoned: The sign-in has been inactive for a long period of time, thus it's considered as abandoned and need to start over.
     */
    public let status: Status?
    
    public enum Status: String, Decodable {
        case needsIdentifier = "needs_identifier"
        case needsFirstFactor = "needs_first_factor"
        case needsSecondFactor = "needs_second_factor"
        case complete = "complete"
        case abandoned = "abandoned"
    }
    
    /**
     Array of all the authentication identifiers that are supported for this sign in.
     
     Examples of this could be:
     - email_address
     - phone_number
     - web3_wallet
     - username
     */
    let supportedIdentifiers: [String]
    
    /**
     Array of the first factors that are supported in the current sign-in. Each factor contains information about the verification strategy that can be used.
     
     For example:
     - email_code for email addresses
     - phone_code for phone numbers
     
     As well as the identifier that the factor refers to.
     */
    @DecodableDefault.EmptyList private(set) public var supportedFirstFactors: [SignInFactor]
    
    /**
     Array of the second factors that are supported in the current sign-in. Each factor contains information about the verification strategy that can be used.
     
     For example:
     - email_code for email addresses
     - phone_code for phone numbers
     
     As well as the identifier that the factor refers to. Please note that this property is populated only when the first factor is verified.
     */
    let supportedSecondFactors: [String]?
    
    /// The state of the verification process for the selected first factor. Please note that this property contains an empty verification object initially, since there is no first factor selected. You need to call the prepareFirstFactor method in order to start the verification process.
    public let firstFactorVerification: Verification?
    
    /// The state of the verification process for the selected second factor. Similar to firstFactorVerification, this property contains an empty verification object initially, since there is no second factor selected. For the phone_code strategy, you need to call the prepareSecondFactor method in order to start the verification process. For the totp strategy, you can directly attempt.
    let secondFactorVerification: Verification?
    
    /// The authentication identifier value for the current sign-in.
    public let identifier: String?
    
    /// An object containing information about the user of the current sign-in. This property is populated only once an identifier is given to the SignIn object.
    public let userData: UserData?
    
    /// The identifier of the session that was created upon completion of the current sign-in. The value of this property is null if the sign-in status is not complete.
    let createdSessionId: String?
    
    ///
    let abandonAt: Date
}

extension SignIn {
        
    public struct CreateParams: Encodable {
        public init(
            identifier: String? = nil,
            strategy: Strategy? = nil,
            password: String? = nil,
            redirectUrl: String? = nil,
            transfer: Bool? = nil
        ) {
            self.identifier = identifier
            self.strategy = strategy?.stringValue
            self.password = password
            self.redirectUrl = redirectUrl
            self.transfer = transfer
        }
        
        public let identifier: String?
        public let strategy: String?
        public let password: String?
        public let redirectUrl: String?
        public let transfer: Bool?
    }
    
    public struct PrepareFirstFactorParams: Encodable {
        public init(
            strategy: Strategy,
            emailAddressId: String? = nil,
            phoneNumberId: String? = nil
        ) {
            self.strategy = strategy.stringValue
            self.emailAddressId = emailAddressId
            self.phoneNumberId = phoneNumberId
        }
        
        public let strategy: String
        public let emailAddressId: String?
        public let phoneNumberId: String?
    }
    
    public struct AttemptFirstFactorParams: Encodable {
        public init(
            code: String? = nil,
            strategy: Strategy
        ) {
            self.code = code
            self.strategy = strategy.stringValue
        }
        
        public let code: String?
        public let strategy: String
    }
    
    public struct GetParams: Encodable {
        public init(rotatingTokenNonce: String? = nil) {
            self.rotatingTokenNonce = rotatingTokenNonce
        }
        
        public var rotatingTokenNonce: String?
    }
    
}

extension SignIn {
    
    public enum CreateStrategy {
        case emailCode(email: String)
        case phoneCode(phoneNumber: String)
        case oauth(provider: OAuthProvider)
        case transfer
    }
    
    private func createParams(for strategy: CreateStrategy) -> CreateParams {
        switch strategy {
        case .emailCode(let identifier):
            return .init(identifier: identifier)
        case .phoneCode(let phoneNumber):
            return .init(identifier: phoneNumber)
        case .oauth(let provider):
            return .init(strategy: .oauth(provider), redirectUrl: "clerk://")
        case .transfer:
            return .init(transfer: true)
        }
    }
    
    public enum PrepareStrategy {
        case emailCode
        case phoneCode
    }
    
    private func prepareParams(for strategy: PrepareStrategy) -> PrepareFirstFactorParams {
        switch strategy {
        case .emailCode:
            return .init(strategy: .emailCode, emailAddressId: factorId(for: .emailCode))
        case .phoneCode:
            return .init(strategy: .phoneCode, phoneNumberId: factorId(for: .phoneCode))
        }
    }
    
    public enum AttemptStrategy {
        case emailCode(code: String)
        case phoneCode(code: String)
    }
    
    private func attemptParams(for strategy: AttemptStrategy) -> AttemptFirstFactorParams {
        switch strategy {
        case .emailCode(let code):
            return .init(code: code, strategy: .emailCode)
        case .phoneCode(let code):
            return .init(code: code, strategy: .phoneCode)
        }
    }
    
    private func factorId(for strategy: Strategy) -> String? {
        let factor = Clerk.shared.client
            .signIn
            .supportedFirstFactors
            .first(where: { $0.strategy == strategy.stringValue })
        
        switch strategy {
        case .emailCode:
            return factor?.emailAddressId
        case .phoneCode:
            return factor?.phoneNumberId
        default:
            return nil
        }
    }
    
}

extension SignIn {
    
    /**
     Use this method to kick-off the sign in flow. It creates a SignIn object and stores the sign in lifecycle state.

     Depending on the use-case and the params you pass to the create method, it can either complete the sign in process in one go, or simply collect part of the necessary data for completing authentication at a later stage.
     */
    @MainActor
    public func create(_ strategy: CreateStrategy) async throws {
        let params = createParams(for: strategy)
        let request = APIEndpoint
            .v1
            .client
            .signIns
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    /**
     Begins the first factor verification process. This is a required step in order to complete a sign in, as users should be verified at least by one factor of authentication.

     Common scenarios are one-time code (OTP) or social account (SSO) verification. This is determined by the accepted strategy parameter values. Each authentication identifier supports different strategies.
     */
    @MainActor
    public func prepareFirstFactor(_ strategy: PrepareStrategy) async throws {
        let params = prepareParams(for: strategy)
        let request = APIEndpoint
            .v1
            .client
            .signIns
            .id(id)
            .prepareFirstFactor
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    /**
     Attempts to complete the first factor verification process. This is a required step in order to complete a sign in, as users should be verified at least by one factor of authentication.

     Make sure that a SignIn object already exists before you call this method, either by first calling SignIn.create or SignIn.prepareFirstFactor. The only strategy that does not require a verification to have already been prepared before attempting to complete it, is the password strategy.

     Depending on the strategy that was selected when the verification was prepared, the method parameters should be different.
     */
    @MainActor
    public func attemptFirstFactor(_ strategy: AttemptStrategy) async throws {
        let params = attemptParams(for: strategy)
        let request = APIEndpoint
            .v1
            .client
            .signIns
            .id(id)
            .attemptFirstFactor
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    @MainActor
    public func get(_ params: GetParams? = nil) async throws {
        let request = APIEndpoint
            .v1
            .client
            .signIns
            .id(id)
            .get(params: params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
}
