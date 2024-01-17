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
public class SignIn: Codable {
    public init(
        id: String = "",
        status: SignIn.Status? = nil,
        supportedIdentifiers: [String] = [],
        supportedFirstFactors: [Factor] = [],
        supportedSecondFactors: [Factor] = [],
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
    
    public enum Status: String, Codable {
        case needsIdentifier = "needs_identifier"
        case needsFirstFactor = "needs_first_factor"
        case needsSecondFactor = "needs_second_factor"
        case complete = "complete"
        case abandoned = "abandoned"
        case needsNewPassword = "needs_new_password"
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
    @DecodableDefault.EmptyList private(set) public var supportedFirstFactors: [Factor]
    
    /**
     Array of the second factors that are supported in the current sign-in. Each factor contains information about the verification strategy that can be used.
     
     For example:
     - email_code for email addresses
     - phone_code for phone numbers
     
     As well as the identifier that the factor refers to. Please note that this property is populated only when the first factor is verified.
     */
    @DecodableDefault.EmptyList private(set) public var supportedSecondFactors: [Factor]
    
    /// The state of the verification process for the selected first factor. Please note that this property contains an empty verification object initially, since there is no first factor selected. You need to call the prepareFirstFactor method in order to start the verification process.
    public let firstFactorVerification: Verification?
    
    /// The state of the verification process for the selected second factor. Similar to firstFactorVerification, this property contains an empty verification object initially, since there is no second factor selected. For the phone_code strategy, you need to call the prepareSecondFactor method in order to start the verification process. For the totp strategy, you can directly attempt.
    public let secondFactorVerification: Verification?
    
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
            strategy: Strategy,
            code: String? = nil,
            password: String? = nil
        ) {
            self.strategy = strategy.stringValue
            self.code = code
            self.password = password
        }
        
        public let strategy: String
        public let code: String?
        public let password: String?
    }
    
    public struct PrepareSecondFactorParams: Encodable {
        public init(strategy: Strategy) {
            self.strategy = strategy.stringValue
        }
        
        public let strategy: String
    }
    
    public struct AttemptSecondFactorParams: Encodable {
        public init(
            strategy: Strategy,
            code: String? = nil
        ) {
            self.strategy = strategy.stringValue
            self.code = code
        }
        
        public let strategy: String
        public let code: String?
    }
    
    public struct GetParams: Encodable {
        public init(rotatingTokenNonce: String? = nil) {
            self.rotatingTokenNonce = rotatingTokenNonce
        }
        
        public var rotatingTokenNonce: String?
    }
    
    public struct ResetPasswordParams: Encodable {
        public init(
            password: String,
            signOutOfOtherSessions: Bool
        ) {
            self.password = password
            self.signOutOfOtherSessions = signOutOfOtherSessions
        }
        
        let password: String
        let signOutOfOtherSessions: Bool
    }
    
}

extension SignIn {
    
    public enum CreateStrategy {
        case identifier(_ identifier: String)
        case oauth(provider: OAuthProvider)
        case transfer
    }
    
    private func createParams(for strategy: CreateStrategy) -> CreateParams {
        switch strategy {
        case .identifier(let identifier):
            return .init(identifier: identifier)
        case .oauth(let provider):
            return .init(strategy: .oauth(provider), redirectUrl: "clerk://")
        case .transfer:
            return .init(transfer: true)
        }
    }
    
    public enum PrepareFirstFactorStrategy {
        case emailCode
        case emailLink
        case phoneCode
        case resetPasswordEmailCode
        case resetPasswordPhoneCode
    }
    
    private func prepareFirstFactorParams(for prepareStrategy: PrepareFirstFactorStrategy) -> PrepareFirstFactorParams {
        let strategy: Strategy = switch prepareStrategy {
        case .emailCode: .emailCode
        case .emailLink: .emailLink
        case .phoneCode: .phoneCode
        case .resetPasswordEmailCode: .resetPasswordEmailCode
        case .resetPasswordPhoneCode: .resetPasswordPhoneCode
        }
        
        switch prepareStrategy {
        case .emailCode, .emailLink, .resetPasswordEmailCode:
            return .init(strategy: strategy, emailAddressId: factorId(for: strategy))
        case .phoneCode, .resetPasswordPhoneCode:
            return .init(strategy: strategy, phoneNumberId: factorId(for: strategy))
        }
    }
    
    public enum AttemptFirstFactorStrategy {
        case password(password: String)
        case emailCode(code: String)
        case phoneCode(code: String)
        case resetEmailCode(code: String)
        case resetPhoneCode(code: String)
    }
    
    private func attemptFirstFactorParams(for strategy: AttemptFirstFactorStrategy) -> AttemptFirstFactorParams {
        switch strategy {
        case .password(let password):
            return .init(strategy: .password, password: password)
        case .emailCode(let code):
            return .init(strategy: .emailCode, code: code)
        case .phoneCode(let code):
            return .init(strategy: .phoneCode, code: code)
        case .resetEmailCode(let code):
            return  .init(strategy: .resetPasswordEmailCode, code: code)
        case .resetPhoneCode(let code):
            return .init(strategy: .resetPasswordPhoneCode, code: code)
        }
    }
    
    public enum PrepareSecondFactorStrategy {
        case phoneCode
        case totp
    }
    
    private func prepareSecondFactorParams(for prepareStrategy: PrepareSecondFactorStrategy) -> PrepareSecondFactorParams {
        switch prepareStrategy {
        case .phoneCode:
            return .init(strategy: .phoneCode)
        case .totp:
            return .init(strategy: .totp)
        }
    }
    
    public enum AttemptSecondFactorStrategy {
        case phoneCode(code: String)
        case totp(code: String)
        case backupCode(code: String)
    }
    
    private func attemptSecondFactorParams(for strategy: AttemptSecondFactorStrategy) -> AttemptSecondFactorParams {
        switch strategy {
        case .phoneCode(let code):
            return .init(strategy: .phoneCode, code: code)
        case .totp(let code):
            return .init(strategy: .totp, code: code)
        case .backupCode(let code):
            return .init(strategy: .backupCode, code: code)
        }
    }
    
    private func factorId(for strategy: Strategy) -> String? {
        let signIn = Clerk.shared.client.signIn
        let allSignInFactors = signIn.supportedFirstFactors + signIn.supportedSecondFactors
        let factor = allSignInFactors.first(where: { $0.verificationStrategy == strategy })
        
        switch strategy {
        case .emailCode, .emailLink, .resetPasswordEmailCode:
            return factor?.emailAddressId
        case .phoneCode, .resetPasswordPhoneCode:
            return factor?.phoneNumberId
        default:
            return nil
        }
    }
    
}

extension SignIn {
    
    // First Factor
    
    public var currentFirstFactor: Factor? {
        guard status == .needsFirstFactor else { return nil }

        if let firstFactorVerification,
           let currentFirstFactor = supportedFirstFactors.first(where: { $0.verificationStrategy == firstFactorVerification.verificationStrategy })
        {
            return currentFirstFactor
        }
        
        return startingSignInFirstFactor
    }
    
    private var startingSignInFirstFactor: Factor? {
        let preferredStrategy = Clerk.shared.environment.displayConfig.preferredSignInStrategy
        let firstFactors = alternativeFirstFactors(currentStrategy: nil) // filters out reset strategies and oauth
        
        switch preferredStrategy {
        case .password:
            let sortedFactors = firstFactors.sorted { $0.sortOrderPasswordPreferred < $1.sortOrderPasswordPreferred }
            if let passwordFactor = sortedFactors.first(where: { $0.verificationStrategy == .password }) {
                return passwordFactor
            }
            
            return sortedFactors.first(where: { $0.safeIdentifier == identifier }) ?? firstFactors.first
        case .otp:
            let sortedFactors = firstFactors.sorted { $0.sortOrderOTPPreferred < $1.sortOrderOTPPreferred }
            return sortedFactors.first(where: { $0.safeIdentifier == identifier }) ?? firstFactors.first
        }
    }
    
    public var firstFactorHasBeenPrepared: Bool {
        firstFactorVerification != nil
    }
    
    public func alternativeFirstFactors(currentStrategy: Strategy?) -> [Factor] {
        // Remove the current factor, reset factors, oauth factors
        let firstFactors = supportedFirstFactors.filter { factor in
            factor.verificationStrategy != currentStrategy &&
            !factor.isResetStrategy &&
            !(factor.verificationStrategy?.stringValue ?? "").hasPrefix("oauth_")
        }
                
        return firstFactors
    }
    
    public func firstFactor(for strategy: Strategy) -> Factor? {
        supportedFirstFactors.first(where: { $0.verificationStrategy == strategy })
    }
    
    // Second Factor
    
    public var currentSecondFactor: Factor? {
        guard status == .needsSecondFactor else { return nil }

        if let secondFactorVerification,
           let currentSecondFactor = supportedSecondFactors.first(where: { $0.verificationStrategy == secondFactorVerification.verificationStrategy })
        {
            return currentSecondFactor
        }

        return startingSignInSecondFactor
    }
    
    // The priority of second factors is: TOTP -> Phone code -> any other factor
    private var startingSignInSecondFactor: Factor? {
        if let totp = supportedSecondFactors.first(where: { $0.verificationStrategy == .totp }) {
            return totp
        }
        
        if let phoneCode = supportedSecondFactors.first(where: { $0.verificationStrategy == .phoneCode }) {
            return phoneCode
        }
        
        return supportedSecondFactors.first
    }
    
    public var secondFactorHasBeenPrepared: Bool {
        secondFactorVerification != nil
    }
    
    public func alternativeSecondFactors(currentStrategy: Strategy?) -> [Factor] {
        supportedSecondFactors.filter { $0.verificationStrategy != currentStrategy }
    }
    
    public func secondFactor(for strategy: Strategy) -> Factor? {
        supportedSecondFactors.first(where: { $0.verificationStrategy == strategy })
    }
        
    // Reset Password
    
    public var resetPasswordStrategy: SignIn.PrepareFirstFactorStrategy? {
        if supportedFirstFactors.contains(where: { $0.verificationStrategy == .resetPasswordEmailCode }) {
            return .resetPasswordEmailCode
        }
        
        if supportedFirstFactors.contains(where: { $0.verificationStrategy == .resetPasswordPhoneCode }) {
            return .resetPasswordPhoneCode
        }
        
        return nil
    }
    
}

extension SignIn {
    
    public func startExternalAuth() async throws {
        guard
            let redirectUrl = firstFactorVerification?.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL not provided. Unable to start authentication flow.")
        }
        
        let authSession = ExternalAuthWebSession(url: url, authAction: .signIn)
        try await authSession.start()
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
    public func prepareFirstFactor(_ strategy: PrepareFirstFactorStrategy) async throws {
        let params = prepareFirstFactorParams(for: strategy)
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
    public func attemptFirstFactor(_ strategy: AttemptFirstFactorStrategy) async throws {
        let params = attemptFirstFactorParams(for: strategy)
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
    
    /**
     Begins the second factor verification process. This step is optional in order to complete a sign in.
     
     A common scenario for the second step verification (2FA) is to require a one-time code (OTP) as proof of identity. This is determined by the accepted strategy parameter values. Each authentication identifier supports different strategies.
     
     While the phone_code strategy requires preparation, the totp strategy does not - the user can directly attempt the second factor verification in that case.
     */
    @MainActor
    public func prepareSecondFactor(_ strategy: PrepareSecondFactorStrategy) async throws {
        let params = prepareSecondFactorParams(for: strategy)
        let request = APIEndpoint
            .v1
            .client
            .signIns
            .id(id)
            .prepareSecondFactor
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    /**
     Attempts to complete the second factor verification process (2FA). This step is optional in order to complete a sign in.

     For the phone_code strategy, make sure that a verification has already been prepared before you call this method, by first calling SignIn.prepareSecondFactor. Depending on the strategy that was selected when the verification was prepared, the method parameters should be different.

     The totp strategy can directly be attempted, without the need for preparation.
     */
    @MainActor
    public func attemptSecondFactor(_ strategy: AttemptSecondFactorStrategy) async throws {
        let params = attemptSecondFactorParams(for: strategy)
        let request = APIEndpoint
            .v1
            .client
            .signIns
            .id(id)
            .attemptSecondFactor
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
    
    /// Resets a user's password.
    @MainActor
    public func resetPassword(_ params: ResetPasswordParams) async throws {
        let request = APIEndpoint
            .v1
            .client
            .signIns
            .id(id)
            .resetPassword
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
}
