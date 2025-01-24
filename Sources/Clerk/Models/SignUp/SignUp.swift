//
//  SignUp.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import AuthenticationServices

/// The `SignUp` object holds the state of the current sign-up and provides helper methods to navigate and complete the sign-up process.
/// Once a sign-up is complete, a new user is created.
///
/// ### The Sign-Up Process:
/// 1. **Initiate the Sign-Up**:
///    Begin the sign-up process by collecting the user's authentication information and passing the appropriate parameters to the `create()` method.
///
/// 2. **Prepare the Verification**:
///    The system will prepare the necessary verification steps to confirm the user's information.
///
/// 3. **Complete the Verification**:
///    Attempt to complete the verification by following the required steps based on the collected authentication data.
///
/// 4. **Sign Up Complete**:
///    If the verification is successful, the newly created session is set as the active session.
public struct SignUp: Codable, Sendable, Equatable, Hashable {
    
    /// The unique identifier of the current sign-up.
    public let id: String
    
    /// The status of the current sign-up.
    ///
    /// See ``SignUp/Status-swift.enum`` for supported values.
    public let status: Status
    
    /// An array of all the required fields that need to be supplied and verified in order for this sign-up to be marked as complete and converted into a user.
    public let requiredFields: [String]
    
    /// An array of all the fields that can be supplied to the sign-up, but their absence does not prevent the sign-up from being marked as complete.
    public let optionalFields: [String]
    
    /// An array of all the fields whose values are not supplied yet but they are mandatory in order for a sign-up to be marked as complete.
    public let missingFields: [String]
    
    /// An array of all the fields whose values have been supplied, but they need additional verification in order for them to be accepted.
    ///
    /// Examples of such fields are `email_address` and `phone_number`.
    public let unverifiedFields: [String]
    
    /// An object that contains information about all the verifications that are in-flight.
    public let verifications: [String: Verification?]
    
    /// The username supplied to the current sign-up. Only supported if username is enabled in the instance settings.
    public let username: String?
    
    /// The email address supplied to the current sign-up. Only supported if email address is enabled in the instance settings.
    public let emailAddress: String?
    
    /// The user's phone number in E.164 format. Only supported if phone number is enabled in the instance settings.
    public let phoneNumber: String?
    
    /// The Web3 wallet address, made up of 0x + 40 hexadecimal characters. Only supported if Web3 authentication is enabled in the instance settings.
    public let web3Wallet: String?

    /// The value of this attribute is true if a password was supplied to the current sign-up. Only supported if password is enabled in the instance settings.
    public let passwordEnabled: Bool
    
    /// The first name supplied to the current sign-up. Only supported if name is enabled in the instance settings.
    public let firstName: String?
    
    /// The last name supplied to the current sign-up. Only supported if name is enabled in the instance settings.
    public let lastName: String?
    
    /// Metadata that can be read and set from the frontend. Once the sign-up is complete, the value of this field will be automatically copied to the newly created user's unsafe metadata. One common use case for this attribute is to use it to implement custom fields that can be collected during sign-up and will automatically be attached to the created User object.
    public let unsafeMetadata: JSON?
    
    /// The identifier of the newly-created session. This attribute is populated only when the sign-up is complete.
    public let createdSessionId: String?
    
    /// The identifier of the newly-created user. This attribute is populated only when the sign-up is complete.
    public  let createdUserId: String?
    
    /// The date when the sign-up was abandoned by the user.
    public let abandonAt: Date
}

extension SignUp {
    
    /// Initiates a new sign-up process and returns a `SignUp` object based on the provided strategy and optional parameters.
    ///
    /// This method initiates a new sign-up process by sending the appropriate parameters to Clerk's API.
    /// It deactivates any existing sign-up process and stores the sign-up lifecycle state in the `status` property of the new `SignUp` object.
    /// If required fields are provided, the sign-up process can be completed in one step. If not, Clerk's flexible sign-up process allows multi-step flows.
    ///
    /// - Parameters:
    ///   - strategy: The strategy to use for creating the sign-up. This defines the parameters used for the sign-up process. See ``SignUp/CreateStrategy`` for available strategies.
    ///   - legalAccepted: A Boolean value indicating whether the user has accepted the legal terms. This is optional and, if provided, will be included in the sign-up request.
    ///
    /// - Throws:
    ///   - ``ClerkClientError`` if the request fails or the provided parameters are invalid.
    ///
    /// - Returns: A `SignUp` object containing the current status and details of the sign-up process. The `status` property reflects the current state of the sign-up.
    ///
    /// ### Example Usage:
    /// ```swift
    /// let signUp = try await SignUp.create(strategy: .oauth(provider: .google), legalAccepted: true)
    /// ```
    @discardableResult @MainActor
    public static func create(strategy: SignUp.CreateStrategy, legalAccepted: Bool? = nil) async throws -> SignUp {
        var params = strategy.params
        params.legalAccepted = legalAccepted
        let request = ClerkFAPI.v1.client.signUps.post(params)
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// This method is used to update the current sign-up.
    ///
    /// This method is used to modify the details of an ongoing sign-up process.
    /// It allows you to update any fields previously specified during the sign-up flow,
    /// such as personal information, email, phone number, or other attributes.
    ///
    /// - Parameter params: An instance of ``SignUp/UpdateParams`` (alias of ``SignUp/CreateParams``) containing the fields to update.
    ///   Fields provided in `params` will overwrite the corresponding fields in the current sign-up.
    ///
    /// - Throws: An error if the update operation fails, such as due to invalid parameters or network issues.
    ///
    /// - Returns: The updated `SignUp` object reflecting the changes.
    @discardableResult @MainActor
    public func update(params: UpdateParams) async throws -> SignUp {
        let request = ClerkFAPI.v1.client.signUps.id(id).patch(params)
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// The `prepareVerification` method is used to initiate the verification process for a field that requires it.
    ///
    /// As mentioned, there are two fields that need to be verified:
    ///
    /// - `emailAddress`: The email address can be verified via an email code. This is a one-time code that is sent
    ///   to the email already provided to the `SignUp` object. The `prepareVerification` sends this email.
    /// - `phoneNumber`: The phone number can be verified via a phone code. This is a one-time code that is sent
    ///   via an SMS to the phone already provided to the `SignUp` object. The `prepareVerification` sends this SMS.
    ///
    /// - Parameter strategy: A `PrepareStrategy` specifying which field requires verification.
    /// - Throws: An error if the request to prepare verification fails.
    /// - Returns: The updated `SignUp` object reflecting the verification initiation.
    @discardableResult @MainActor
    public func prepareVerification(strategy: PrepareStrategy) async throws -> SignUp {
        let request = ClerkFAPI.v1.client.signUps.id(id).prepareVerification.post(strategy.params)
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Attempts to complete the in-flight verification process that corresponds to the given strategy. In order to use this method, you should first initiate a verification process by calling SignUp.prepareVerification.
    ///
    /// Depending on the strategy, the method parameters could differ.
    ///
    /// - Parameter strategy: The strategy to use for the verification attempt. See ``SignUp/AttemptStrategy``
    ///   for supported strategies.
    ///
    /// - Throws: An error if the verification attempt fails.
    ///
    /// - Returns: The updated `SignUp` object reflecting the verification attempt's result.
    @discardableResult @MainActor
    public func attemptVerification(_ strategy: AttemptStrategy) async throws -> SignUp {
        let request = ClerkFAPI.v1.client.signUps.id(id).attemptVerification.post(strategy.params)
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
#if !os(tvOS) && !os(watchOS)
    /// Creates a new ``SignUp`` and initiates an external authentication flow using a redirect-based strategy.
    ///
    /// This function handles the process of creating a ``SignUp`` instance,
    /// starting an external web authentication session, and processing the callback URL upon successful
    /// authentication.
    ///
    /// - Parameters:
    ///   - strategy: The authentication strategy to use for the external authentication flow.
    ///               See ``SignUp/AuthenticateWithRedirectStrategy`` for available options.
    ///   - prefersEphemeralWebBrowserSession: A Boolean indicating whether to prefer an ephemeral web
    ///                                         browser session (default is `false`). When `true`, the session
    ///                                         does not persist cookies or other data between sessions, ensuring
    ///                                         a private browsing experience.
    ///
    /// - Throws: An error of type ``ClerkClientError`` if the redirect URL is missing or invalid, or any errors
    ///           encountered during the sign-up or authentication processes.
    ///
    /// - Returns: ``TransferFlowResult`` object containing the result of the external authentication flow which can be either a ``SignUp`` or ``SignIn``.
    ///
    /// Example:
    /// ```swift
    /// let result = try await SignUp.authenticateWithRedirect(strategy: .oauth(provider: .google))
    /// ```
    @discardableResult @MainActor
    public static func authenticateWithRedirect(strategy: SignUp.AuthenticateWithRedirectStrategy, prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
        let signUp = try await SignUp.create(strategy: strategy.signUpStrategy)
        
        guard
            let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
            let redirectUrl = verification.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }
        
        let authSession = WebAuthentication(url: url, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
        let callbackUrl = try await authSession.start()
        let transferFlowResult = try await handleOAuthCallbackUrl(callbackUrl)
        return transferFlowResult
    }
#endif
    
#if !os(tvOS) && !os(watchOS)
    /// Initiates an external authentication flow using a redirect-based strategy for the current ``SignUp`` instance.
    ///
    /// This function starts an external web authentication session,
    /// and processes the callback URL upon successful authentication.
    ///
    /// - Parameters:
    ///   - prefersEphemeralWebBrowserSession: A Boolean indicating whether to prefer an ephemeral web
    ///                                         browser session (default is `false`). When `true`, the session
    ///                                         does not persist cookies or other data between sessions,
    ///                                         ensuring a private browsing experience.
    ///
    /// - Throws: An error of type ``ClerkClientError`` if the redirect URL is missing or invalid, or any errors
    ///           encountered during the authentication process.
    ///
    /// - Returns: ``TransferFlowResult`` object containing the result of the external authentication flow
    ///            which can be either a ``SignUp`` or ``SignIn``.
    ///
    /// Example:
    /// ```swift
    /// let signUp = try await SignUp.create(strategy: .oauth(provider: .google))
    /// let result = try await signUp.authenticateWithRedirect()
    /// ```
    @discardableResult @MainActor
    public func authenticateWithRedirect(prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
        guard
            let verification = verifications.first(where: { $0.key == "external_account" })?.value,
            let redirectUrl = verification.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }
        
        let authSession = WebAuthentication(
            url: url,
            prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
        )
        
        let callbackUrl = try await authSession.start()
        let transferFlowResult = try await SignUp.handleOAuthCallbackUrl(callbackUrl)
        return transferFlowResult
    }
    #endif
    
    /// Authenticates the user using an ID Token and a specified provider.
    ///
    /// This method facilitates authentication using an ID token provided by a specific authentication provider.
    /// It determines whether the user needs to be transferred to a sign-in flow.
    ///
    /// - Parameters:
    ///   - provider: The identity provider associated with the ID token. See ``IDTokenProvider`` for supported values.
    ///   - idToken: The ID token to use for authentication, obtained from the provider during the sign-in process.
    ///
    /// - Throws:``ClerkClientError``
    ///
    /// - Returns: An ``TransferFlowResult`` containing either a sign-in or a newly created sign-up instance.
    ///
    /// ### Example
    /// ```swift
    /// let result = try await SignUp.authenticateWithIdToken(
    ///     provider: .apple,
    ///     idToken: idToken
    /// )
    /// ```
    @discardableResult @MainActor
    public static func authenticateWithIdToken(provider: IDTokenProvider, idToken: String) async throws -> TransferFlowResult {
        let signUp = try await SignUp.create(strategy: .idToken(provider: provider, idToken: idToken))
        let result = try await signUp.handleTransferFlow()
        return result
    }
    
    /// Authenticates the user using an ID Token and a specified provider.
    ///
    /// This method completes authentication using an ID token provided by a specific authentication provider.
    /// It determines whether the user needs to be transferred to a sign-in flow.
    ///
    /// - Throws:``ClerkClientError``
    ///
    /// - Returns: ``TransferFlowResult`` containing either a sign-in or a newly created sign-up instance.
    ///
    /// ### Example
    /// ```swift
    /// let signUp = try await SignUp.create(strategy: .idToken(provider: .apple, idToken: "idToken"))
    /// let result = try await signUp.authenticateWithIdToken()
    /// ```
    @discardableResult @MainActor
    public func authenticateWithIdToken() async throws -> TransferFlowResult {
        try await self.handleTransferFlow()
    }
}

extension SignUp {
    
    // MARK: - Private Helpers
    
    private var needsTransferToSignIn: Bool {
        verifications.contains(where: { $0.key == "external_account" && $0.value?.status == .transferable })
    }
    
    /// Determines whether or not to return a sign in or sign up object as part of the transfer flow.
    private func handleTransferFlow() async throws -> TransferFlowResult {
        if needsTransferToSignIn == true {
            let signIn = try await SignIn.create(strategy: .transfer)
            return .signIn(signIn)
        } else {
            return .signUp(self)
        }
    }
    
    @discardableResult @MainActor
    private static func handleOAuthCallbackUrl(_ url: URL) async throws -> TransferFlowResult {
        if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
            
            guard let signUp = try await Clerk.shared.client?.signUp?.get(rotatingTokenNonce: nonce) else {
                throw ClerkClientError(message: "Unable to retrieve the current sign up.")
            }
            
            return .signUp(signUp)
            
        } else {
            // transfer flow
            
            guard let signUp = try await Client.get()?.signUp else {
                throw ClerkClientError(message: "Unable to retrive the current sign up.")
            }
            
            let result = try await signUp.handleTransferFlow()
            return result
        }
    }
    
    /// Returns the current sign up.
    @discardableResult @MainActor
    private func get(rotatingTokenNonce: String? = nil) async throws -> SignUp {
        let request = ClerkFAPI.v1.client.signUps.id(id).get(rotatingTokenNonce: rotatingTokenNonce)
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
}
