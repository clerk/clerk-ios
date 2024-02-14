//
//  SignIn.swift
//
//
//  Created by Mike Pitre on 1/30/24.
//

import Foundation

/**
 The SignIn object holds all the state of the current sign in and provides helper methods to navigate and complete the sign in process.
 
 There are two important steps in the sign in flow.
 
 Users must complete a first factor verification. This can be something like providing a password, an email magic link, a one-time code (OTP), a web3 wallet address or providing proof of their identity through an external social account (SSO/OAuth).
 After that, users might need to go through a second verification process. This is the second factor (2FA).
 The SignIn object's properties can be split into logical groups, with each group providing information on different aspects of the sign in flow. These groups can be:
 
 Information about the current sign in status in general and which authentication identifiers, authentication methods and verifications are supported.
 Information about the user and the provided authentication identifier value (email address, phone number or username).Information about each verification, either the first factor (logging in) or the second factor (2FA).
 */
public struct SignIn: Codable {
    
    /// String representing the object's type. Objects of the same type share the same value.
    let object: Object
    
    /// Unique identifier for this sign in.
    let id: String
    
    /// The current status of the sign-in.
    public let status: Status?
    
    /// Array of all the authentication identifiers that are supported for this sign in.
    public let supportedIdentifiers: [SupportedIdentifier]
    
    /// The authentication identifier value for the current sign-in.
    public let identifier: String?
    
    /// Array of the first factors that are supported in the current sign-in. Each factor contains information about the verification strategy that can be used.
    public let supportedFirstFactors: [SignInFactor]?
    
    /// Array of the second factors that are supported in the current sign-in. Each factor contains information about the verification strategy that can be used.
    public let supportedSecondFactors: [SignInFactor]?
    
    /**
     The state of the verification process for the selected first factor.
     Please note that this property contains an empty verification object initially, since there is no first factor selected.
     You need to call the prepareFirstFactor method in order to start the verification process.
     */
    public let firstFactorVerification: Verification?
    
    /**
     The state of the verification process for the selected second factor.
     Similar to `firstFactorVerification`, this property contains an empty verification object initially, since there is no second factor selected.
     For the `phone_code` strategy, you need to call the `prepareSecondFactor` method in order to start the verification process.
     For the `totp` strategy, you can directly attempt.
     */
    public let secondFactorVerification: Verification?
    
    /// An object containing information about the user of the current sign-in. This property is populated only once an identifier is given to the SignIn object.
    public let userData: UserData?
    
    /// The identifier of the session that was created upon completion of the current sign-in. The value of this property is null if the sign-in status is not complete.
    public let createdSessionId: String?
    
    /// The date when the sign-in was abandoned by the user.
    let abandonAt: Date
    
    /// String representing the object's type. Objects of the same type share the same value.
    public enum Object: String, Codable {
        case signInAttempt = "sign_in_attempt"
    }
    
    /// The current status of the sign-in.
    public enum Status: String, Codable {
        /// The authentication identifier hasn't been provided.
        case needsIdentifier = "needs_identifier"
        
        /// First factor verification for the provided identifier needs to be prepared and verified.
        case needsFirstFactor = "needs_first_factor"
        
        /// Second factor verification (2FA) for the provided identifier needs to be prepared and verified.
        case needsSecondFactor = "needs_second_factor"
        
        /// The user needs to set a new password.
        case needsNewPassword = "needs_new_password"
        
        /// The sign-in is complete and the user is authenticated.
        case complete
        
        /// The sign-in has been inactive for a long period of time, thus it's considered as abandoned and needs to start over.
        case abandoned
    }
    
    /// Authentication identifier that is supported for this sign in.
    public enum SupportedIdentifier: String, Codable {
        case emailAddress = "email_address"
        case phoneNumber = "phone_number"
        case username
        case web3Wallet = "web3_wallet"
    }
    
    /// An object containing information about the user of the current sign-in. This property is populated only once an identifier is given to the SignIn object.
    public struct UserData: Codable {
        public let firstName: String?
        public let lastName: String?
        public let imageUrl: String?
        public let hasImage: Bool?
    }
    
    init(
        id: String = "",
        object: Object = .signInAttempt,
        status: Status? = nil,
        supportedIdentifiers: [SupportedIdentifier] = [],
        supportedFirstFactors: [SignInFactor]? = nil,
        firstFactorVerification: Verification? = nil,
        supportedSecondFactors: [SignInFactor]? = nil,
        secondFactorVerification: Verification? = nil,
        identifier: String? = nil,
        userData: UserData? = nil,
        createdSessionId: String? = nil,
        abandonAt: Date = .now
    ) {
        self.id = id
        self.object = object
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
    
    /**
     Use this method to kick-off the sign in flow. It creates a SignIn object and stores the sign-in lifecycle state.
     
     Depending on the use-case and the params you pass to the create method, it can either complete the sign-in process in one go, or simply collect part of the necessary data for completing authentication at a later stage.
     */
    @discardableResult @MainActor
    public func create(strategy: CreateStrategy) async throws -> SignIn {
        let params = createSignInParams(for: strategy)
        let request = ClerkAPI.v1.client.signIns.post(params)
        let response = try await Clerk.apiClient.send(request).value.response
        try await Clerk.shared.client.get()
        return response
    }
    
    public enum CreateStrategy {
        case identifier(_ identifier: String)
        case externalProvider(_ provider: ExternalProvider)
        case transfer
    }
    
    private func createSignInParams(for strategy: CreateStrategy) -> CreateParams {
        switch strategy {
        case .identifier(let identifier):
            return .init(identifier: identifier, redirectUrl: "clerk://")
        case .externalProvider(let provider):
            return .init(strategy: provider.data.strategy, redirectUrl: "clerk://")
        case .transfer:
            return .init(redirectUrl: "clerk://", transfer: true)
        }
    }
    
    public struct CreateParams: Encodable {
        public var identifier: String?
        public var strategy: String?
        public var password: String?
        public var redirectUrl: String?
        public var transfer: Bool?
    }
    
    /// Resets a user's password.
    @discardableResult @MainActor
    public func resetPassword(_ params: ResetPasswordParams) async throws -> SignIn {
        let request = ClerkAPI.v1.client.signIns.id(id).resetPassword.post(params)
        let response = try await Clerk.apiClient.send(request).value.response
        try await Clerk.shared.client.get()
        return response
    }
    
    public struct ResetPasswordParams: Encodable {
        let password: String
        let signOutOfOtherSessions: Bool
    }
    
    /**
     Begins the first factor verification process. This is a required step in order to complete a sign in, as users should be verified at least by one factor of authentication.
     
     Common scenarios are one-time code (OTP) or social account (SSO) verification. This is determined by the accepted strategy parameter values. Each authentication identifier supports different strategies.
     */
    @discardableResult @MainActor
    public func prepareFirstFactor(for prepareFirstFactorStrategy: PrepareFirstFactorStrategy) async throws -> SignIn {
        let params = prepareFirstFactorParams(for: prepareFirstFactorStrategy)
        let request = ClerkAPI.v1.client.signIns.id(id).prepareFirstFactor.post(params)
        let response = try await Clerk.apiClient.send(request).value.response
        try await Clerk.shared.client.get()
        return response
    }
    
    public enum PrepareFirstFactorStrategy {
        case emailCode
        case emailLink
        case phoneCode
        case resetPasswordEmailCode
        case resetPasswordPhoneCode
    }
    
    private func prepareFirstFactorParams(for prepareFirstFactorStrategy: PrepareFirstFactorStrategy) -> PrepareFirstFactorParams {
        let strategy: Strategy = switch prepareFirstFactorStrategy {
        case .emailCode: .emailCode
        case .emailLink: .emailLink
        case .phoneCode: .phoneCode
        case .resetPasswordEmailCode: .resetPasswordEmailCode
        case .resetPasswordPhoneCode: .resetPasswordPhoneCode
        }
        
        switch prepareFirstFactorStrategy {
        case .emailCode, .emailLink, .resetPasswordEmailCode:
            return .init(strategy: strategy.stringValue, emailAddressId: factorId(for: strategy))
        case .phoneCode, .resetPasswordPhoneCode:
            return .init(strategy: strategy.stringValue, phoneNumberId: factorId(for: strategy))
        }
    }
    
    public struct PrepareFirstFactorParams: Encodable {
        public let strategy: String
        public var emailAddressId: String?
        public var phoneNumberId: String?
    }
    
    /**
     Attempts to complete the first factor verification process. This is a required step in order to complete a sign in, as users should be verified at least by one factor of authentication.
     
     Make sure that a SignIn object already exists before you call this method, either by first calling SignIn.create or SignIn.prepareFirstFactor. The only strategy that does not require a verification to have already been prepared before attempting to complete it, is the password strategy.
     
     Depending on the strategy that was selected when the verification was prepared, the method parameters should be different.
     */
    @discardableResult @MainActor
    public func attemptFirstFactor(for attemptFirstFactorStrategy: AttemptFirstFactorStrategy) async throws -> SignIn {
        let params = attemptFirstFactorParams(for: attemptFirstFactorStrategy)
        let request = ClerkAPI.v1.client.signIns.id(id).attemptFirstFactor.post(params)
        let response = try await Clerk.apiClient.send(request).value.response
        try await Clerk.shared.client.get()
        return response
    }
    
    public enum AttemptFirstFactorStrategy {
        case password(password: String)
        case emailCode(code: String)
        case phoneCode(code: String)
        case resetPasswordEmailCode(code: String)
        case resetPasswordPhoneCode(code: String)
    }
    
    private func attemptFirstFactorParams(for strategy: AttemptFirstFactorStrategy) -> AttemptFirstFactorParams {
        switch strategy {
        case .password(let password):
            return .init(strategy: Strategy.password.stringValue, password: password)
        case .emailCode(let code):
            return .init(strategy: Strategy.emailCode.stringValue, code: code)
        case .phoneCode(let code):
            return .init(strategy: Strategy.phoneCode.stringValue, code: code)
        case .resetPasswordEmailCode(let code):
            return  .init(strategy: Strategy.resetPasswordEmailCode.stringValue, code: code)
        case .resetPasswordPhoneCode(let code):
            return .init(strategy: Strategy.resetPasswordPhoneCode.stringValue, code: code)
        }
    }
    
    public struct AttemptFirstFactorParams: Encodable {
        public let strategy: String
        public var code: String?
        public var password: String?
    }
    
    /**
     Begins the second factor verification process. This step is optional in order to complete a sign in.
     
     A common scenario for the second step verification (2FA) is to require a one-time code (OTP) as proof of identity. This is determined by the accepted strategy parameter values. Each authentication identifier supports different strategies.
     */
    @discardableResult @MainActor
    public func prepareSecondFactor(for prepareSecondFactorStrategy: PrepareSecondFactorStrategy) async throws -> SignIn {
        let params = prepareSecondFactorParams(for: prepareSecondFactorStrategy)
        let request = ClerkAPI.v1.client.signIns.id(id).prepareSecondFactor.post(params)
        let response = try await Clerk.apiClient.send(request).value.response
        try await Clerk.shared.client.get()
        return response
    }
    
    public enum PrepareSecondFactorStrategy {
        case phoneCode
    }
    
    private func prepareSecondFactorParams(for prepareSecondFactorStrategy: PrepareSecondFactorStrategy) -> PrepareSecondFactorParams {
        switch prepareSecondFactorStrategy {
        case .phoneCode:
            return .init(strategy: Strategy.phoneCode.stringValue)
        }
    }
    
    struct PrepareSecondFactorParams: Encodable {
        public let strategy: String
    }
    
    /**
     Attempts to complete the second factor verification process (2FA). This step is optional in order to complete a sign in.
     
     For the phone_code strategy, make sure that a verification has already been prepared before you call this method, by first calling SignIn.prepareSecondFactor. Depending on the strategy that was selected when the verification was prepared, the method parameters should be different.
     
     The totp strategy can directly be attempted, without the need for preparation.
     */
    @discardableResult @MainActor
    public func attemptSecondFactor(for strategy: AttemptSecondFactorStrategy) async throws -> SignIn {
        let params = attemptSecondFactorParams(for: strategy)
        let request = ClerkAPI.v1.client.signIns.id(id).attemptSecondFactor.post(params)
        let response = try await Clerk.apiClient.send(request).value.response
        try await Clerk.shared.client.get()
        return response
    }
    
    public enum AttemptSecondFactorStrategy {
        case phoneCode(code: String)
        case totp(code: String)
        case backupCode(code: String)
    }
    
    private func attemptSecondFactorParams(for strategy: AttemptSecondFactorStrategy) -> AttemptSecondFactorParams {
        switch strategy {
        case .phoneCode(let code):
            return .init(strategy: Strategy.phoneCode.stringValue, code: code)
        case .totp(let code):
            return .init(strategy: Strategy.totp.stringValue, code: code)
        case .backupCode(let code):
            return .init(strategy: Strategy.backupCode.stringValue, code: code)
        }
    }
    
    public struct AttemptSecondFactorParams: Encodable {
        public let strategy: String
        public let code: String
    }
    
    /// Returns the current sign-in.
    @discardableResult @MainActor
    public func get(rotatingTokenNonce: String? = nil) async throws -> SignIn {
        let request = ClerkAPI.v1.client.signIns.id(id).get(rotatingTokenNonce: rotatingTokenNonce)
        let response = try await Clerk.apiClient.send(request).value.response
        try await Clerk.shared.client.get()
        return response
    }
    
    /// Starts an external authentication web session at the provided `externalVerificationRedirectUrl`.
    @MainActor
    public func startExternalAuth() async throws {
        guard let redirectUrl = firstFactorVerification?.externalVerificationRedirectUrl, let url = URL(string: redirectUrl) else {
            throw ClerkClientError(message: "Redirect URL not provided. Unable to start external authentication flow.")
        }
        
        let authSession = ExternalAuthWebSession(url: url, authAction: .signIn)
        try await authSession.start()
    }
}

extension SignIn {
    
    // First SignInFactor
    
    var currentFirstFactor: SignInFactor? {        
        if let firstFactorVerification,
           let currentFirstFactor = supportedFirstFactors?.first(where: { $0.strategy == firstFactorVerification.strategy }) {
            return currentFirstFactor
        }
        
        return startingSignInFirstFactor
    }
    
    private var startingSignInFirstFactor: SignInFactor? {
        let preferredStrategy = Clerk.shared.environment.displayConfig.preferredSignInStrategy
        let firstFactors = alternativeFirstFactors(currentFactor: nil) // filters out reset strategies and oauth
        
        switch preferredStrategy {
        case .password:
            let sortedFactors = firstFactors.sorted { $0.sortOrderPasswordPreferred < $1.sortOrderPasswordPreferred }
            if let passwordFactor = sortedFactors.first(where: { $0.strategyEnum == .password }) {
                return passwordFactor
            }
            
            return sortedFactors.first(where: { $0.safeIdentifier == identifier }) ?? firstFactors.first
        case .otp:
            let sortedFactors = firstFactors.sorted { $0.sortOrderOTPPreferred < $1.sortOrderOTPPreferred }
            return sortedFactors.first(where: { $0.safeIdentifier == identifier }) ?? firstFactors.first
        }
    }
    
    var firstFactorHasBeenPrepared: Bool {
        firstFactorVerification != nil
    }
    
    func alternativeFirstFactors(currentFactor: SignInFactor?) -> [SignInFactor] {
        // Remove the current factor, reset factors, oauth factors
        let firstFactors = supportedFirstFactors?.filter { factor in
            factor.strategy != currentFactor?.strategy &&
            factor.strategyEnum?.isResetStrategy == false  &&
            !(factor.strategy).hasPrefix("oauth_")
        }
        
        return firstFactors ?? []
    }
    
    func firstFactor(for strategy: Strategy) -> SignInFactor? {
        supportedFirstFactors?.first(where: { $0.strategyEnum == strategy })
    }
    
    // Second SignInFactor
    
    var currentSecondFactor: SignInFactor? {
        guard status == .needsSecondFactor else { return nil }
        
        if let secondFactorVerification,
           let currentSecondFactor = supportedSecondFactors?.first(where: { $0.strategy == secondFactorVerification.strategy })
        {
            return currentSecondFactor
        }
        
        return startingSignInSecondFactor
    }
    
    // The priority of second factors is: TOTP -> Phone code -> any other factor
    private var startingSignInSecondFactor: SignInFactor? {
        if let totp = supportedSecondFactors?.first(where: { $0.strategyEnum == .totp }) {
            return totp
        }
        
        if let phoneCode = supportedSecondFactors?.first(where: { $0.strategyEnum == .phoneCode }) {
            return phoneCode
        }
        
        return supportedSecondFactors?.first
    }
    
    var secondFactorHasBeenPrepared: Bool {
        secondFactorVerification != nil
    }
    
    func alternativeSecondFactors(currentFactor: SignInFactor?) -> [SignInFactor] {
        supportedSecondFactors?.filter { $0.strategy != currentFactor?.strategy } ?? []
    }
    
    func secondFactor(for strategy: Strategy) -> SignInFactor? {
        supportedSecondFactors?.first(where: { $0.strategyEnum == strategy })
    }
    
    func factorId(for strategy: Strategy) -> String? {
        let signInFactors = (supportedFirstFactors ?? []) + (supportedSecondFactors ?? [])
        let signInFactor = signInFactors.first(where: { $0.strategyEnum == strategy })
        
        switch strategy {
        case .emailCode, .emailLink, .resetPasswordEmailCode:
            return signInFactor?.emailAddressId
        case .phoneCode, .resetPasswordPhoneCode:
            return signInFactor?.phoneNumberId
        case .web3:
            return signInFactor?.web3WalletId
        default:
            return nil
        }
    }
    
    // Reset Password
    
    var resetPasswordStrategy: SignIn.PrepareFirstFactorStrategy? {
        guard let supportedFirstFactors else { return nil }
        
        if supportedFirstFactors.contains(where: { $0.strategyEnum == .resetPasswordEmailCode }) {
            return .resetPasswordEmailCode
        }
        
        if supportedFirstFactors.contains(where: { $0.strategyEnum == .resetPasswordPhoneCode }) {
            return .resetPasswordPhoneCode
        }
        
        return nil
    }
    
}
