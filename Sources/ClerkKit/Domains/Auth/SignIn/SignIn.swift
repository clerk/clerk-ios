//
//  SignIn.swift
//
//
//  Created by Mike Pitre on 1/30/24.
//

import AuthenticationServices
import FactoryKit
import Foundation

/// The `SignIn` object holds the state of the current sign-in process and provides helper methods
/// to navigate and complete the sign-in lifecycle. This includes managing the first and second factor
/// verifications, as well as creating a new session.
///
/// ### The following steps outline the sign-in process:
/// 1. **Initiate the Sign-In Process**
///
///    Collect the user's authentication information and pass the appropriate parameters
///    to the `SignIn.create()` method to start the sign-in.
///
/// 2. **Prepare for First Factor Verification**
///
///    Users **must** complete a first factor verification. This can include:
///    - Providing a password
///    - Using an email link
///    - Entering a one-time code (OTP)
///    - Authenticating with a Web3 wallet address
///    - Providing proof of identity through an external social account (SSO/OAuth).
///
/// 3. **Complete First Factor Verification**
///
///    Attempt to verify the user's first factor authentication details.
///
/// 4. **Prepare for Second Factor Verification (Optional)**
///
///    If multi-factor authentication (MFA) is enabled for your application, prepare the
///    second factor verification for users who have set up 2FA for their account.
///
/// 5. **Complete Second Factor Verification**
///
///    Attempt to verify the user's second factor authentication details if MFA is required.

public struct SignIn: Codable, Sendable, Equatable, Hashable {

  /// Unique identifier for this sign in.
  public let id: String

  /// The status of the current sign-in.
  ///
  /// See ``SignIn/Status-swift.enum`` for supported values.
  public let status: Status

  /// Array of all the authentication identifiers that are supported for this sign in.
  public let supportedIdentifiers: [Identifier]?

  /// The authentication identifier value for the current sign-in.
  public let identifier: String?

  /// Array of the first factors that are supported in the current sign-in.
  ///
  ///  Each factor contains information about the verification strategy that can be used. See the `SignInFirstFactor` type reference for more information.
  public let supportedFirstFactors: [Factor]?

  /// Array of the second factors that are supported in the current sign-in.
  ///
  /// Each factor contains information about the verification strategy that can be used. This property is populated only when the first factor is verified. See the `SignInSecondFactor` type reference for more information.
  public let supportedSecondFactors: [Factor]?

  /// The state of the verification process for the selected first factor.
  ///
  /// Initially, this property contains an empty verification object, since there is no first factor selected. You need to call the `prepareFirstFactor` method in order to start the verification process.
  public let firstFactorVerification: Verification?

  /// The state of the verification process for the selected second factor.
  ///
  /// Initially, this property contains an empty verification object, since there is no second factor selected. For the `phone_code` strategy, you need to call the `prepareSecondFactor` method in order to start the verification process. For the `totp` strategy, you can directly attempt.
  public let secondFactorVerification: Verification?

  /// An object containing information about the user of the current sign-in.
  ///
  /// This property is populated only once an identifier is given to the SignIn object.
  public let userData: UserData?

  /// The identifier of the session that was created upon completion of the current sign-in.
  ///
  /// The value of this property is `nil` if the sign-in status is not `complete`.
  public let createdSessionId: String?

  public init(
    id: String,
    status: SignIn.Status,
    supportedIdentifiers: [SignIn.Identifier]? = nil,
    identifier: String? = nil,
    supportedFirstFactors: [Factor]? = nil,
    supportedSecondFactors: [Factor]? = nil,
    firstFactorVerification: Verification? = nil,
    secondFactorVerification: Verification? = nil,
    userData: SignIn.UserData? = nil,
    createdSessionId: String? = nil
  ) {
    self.id = id
    self.status = status
    self.supportedIdentifiers = supportedIdentifiers
    self.identifier = identifier
    self.supportedFirstFactors = supportedFirstFactors
    self.supportedSecondFactors = supportedSecondFactors
    self.firstFactorVerification = firstFactorVerification
    self.secondFactorVerification = secondFactorVerification
    self.userData = userData
    self.createdSessionId = createdSessionId
  }
}

extension SignIn {

  private static var signInService: any SignInServiceProtocol { Container.shared.signInService() }

  private var signInService: any SignInServiceProtocol { Container.shared.signInService() }

  /// Returns a new `SignIn` object based on the parameters you pass to it, and stores the sign-in lifecycle state in the status property. Use this method to initiate the sign-in process.
  ///
  /// - Parameters:
  ///   - strategy: The strategy used to create the sign-in. See ``SignIn/CreateStrategy`` for the available strategies.
  ///
  /// What you must pass to `strategy` depends on which sign-in options you have enabled in your Clerk application instance.
  ///
  /// - Parameters:
  ///   - strategy: The strategy used to create the sign-in. See ``SignIn/CreateStrategy`` for the available strategies.
  ///   - locale: Optional locale override to associate with the request (defaults to the user's preferred locale).
  /// - Returns: A new `SignIn` object.
  /// - Throws: An error if the sign-in request fails.
  ///
  ///### Example Usage:
  /// ```swift
  /// let signIn = try await SignIn.create(
  ///     strategy: .identifier("user@email.com", password: "••••••••"))
  /// )
  /// ```
  @discardableResult @MainActor
  public static func create(strategy: SignIn.CreateStrategy, locale: String? = nil) async throws -> SignIn {
    try await Self.signInService.create(strategy: strategy, locale: locale)
  }

  /// Returns a new `SignIn` object based on the parameters you pass to it, and stores the sign-in lifecycle state in the status property. Use this method to initiate the sign-in process.
  ///
  /// - Parameters:
  ///   - params: A dictionary of parameters used to create the sign-in.
  ///
  /// What you must pass to `params` depends on which sign-in options you have enabled in your Clerk application instance.
  ///
  /// - Returns: A new `SignIn` object.
  /// - Throws: An error if the sign-in request fails.
  ///
  ///### Example Usage:
  /// ```swift
  /// let signIn = try await SignIn.create(
  ///     ["identifier": "user@email.com", "password": "••••••••"]
  /// )
  /// ```
  @discardableResult @MainActor
  public static func create<T: Encodable & Sendable>(_ params: T) async throws -> SignIn {
    try await Self.signInService.createWithParams(params: params)
  }

  /// Resets a user's password.
  ///
  /// This function allows users to reset their password by providing their current password and optionally logging them out of all other active sessions. Once the password is reset, the `SignIn` object is returned, reflecting the updated user session state.
  ///
  /// - Parameters:
  ///   - params: See ``SignIn/ResetPasswordParams`` for the available parameters.
  /// - Returns: A `SignIn` object reflecting the updated user session after the password reset.
  /// - Throws: An error if the password reset attempt fails.
  @discardableResult @MainActor
  public func resetPassword(_ params: ResetPasswordParams) async throws -> SignIn {
    try await signInService.resetPassword(signInId: id, params: params)
  }

  /// Begins the first factor verification process.
  ///
  /// This is a required step to complete a sign-in, as users must be verified by at least one factor of authentication. The verification method is determined by the provided `PrepareFirstFactorStrategy`.
  ///
  /// Common scenarios include one-time code (OTP) or social account (SSO) verification. Each authentication identifier supports different strategies. The status of the first factor verification process can be checked using the `firstFactorVerification` attribute of the returned `SignIn` object.
  ///
  /// - Parameters:
  ///   - prepareFirstFactorStrategy: The strategy to use for the first factor verification. See ``SignIn/PrepareFirstFactorStrategy`` for available strategies.
  /// - Returns: A `SignIn` object reflecting the current state of the sign-in process, including the status of the first factor verification.
  /// - Throws: An error if the first factor preparation fails.
  @discardableResult @MainActor
  public func prepareFirstFactor(strategy: PrepareFirstFactorStrategy) async throws -> SignIn {
    try await signInService.prepareFirstFactor(signInId: id, strategy: strategy, signIn: self)
  }

  /// Attempts to complete the first factor verification process.
  ///
  /// This is a required step in order to complete a sign-in, as users must be verified at least by one factor of authentication. The verification method is determined by the provided `AttemptFirstFactorStrategy`. Depending on the selected strategy, the parameters may vary.
  ///
  ///
  /// - Parameters:
  ///   - attemptFirstFactorStrategy: The strategy to use for the first factor verification. See ``SignIn/AttemptFirstFactorStrategy`` for available strategies and their respective parameters.
  /// - Returns: A `SignIn` object reflecting the current state of the sign-in process, including the status of the first factor verification.
  /// - Throws: An error if the first factor attempt fails.
  /// - Important: Call this method after preparing the verification process using one of the available strategies.
  /// - Important: Ensure that a `SignIn` object already exists before calling this method,  by first calling `SignIn.create` and then `SignIn.prepareFirstFactor`. The only strategy that does not require a prior verification is the `password` strategy.
  @discardableResult @MainActor
  public func attemptFirstFactor(strategy: AttemptFirstFactorStrategy) async throws -> SignIn {
    try await signInService.attemptFirstFactor(signInId: id, strategy: strategy)
  }

  /// Begins the second factor verification process.
  ///
  /// This step is optional in order to complete a sign in.
  ///
  /// A common scenario for the second step verification (2FA) is to require a one-time code (OTP) as proof of identity. This is determined by the accepted strategy parameter values. Each authentication identifier supports different strategies.
  ///
  /// - Parameters:
  ///   - prepareSecondFactorStrategy: An enum that defines the strategy for the second factor verification. See ``SignIn/PrepareSecondFactorStrategy`` for available strategies.
  ///
  /// - Returns: A `SignIn` object. Check the secondFactorVerification attribute for the status of the second factor verification process.
  ///
  /// - Throws: An error if the second factor verification fails.
  @discardableResult @MainActor
  public func prepareSecondFactor(strategy: PrepareSecondFactorStrategy) async throws -> SignIn {
    try await signInService.prepareSecondFactor(signInId: id, strategy: strategy, signIn: self)
  }

  /// Attempts to complete the second factor verification process (2FA).
  ///
  /// This step is optional in order to complete a sign in.
  ///
  /// For the `phone_code` strategy, make sure that a verification has already been prepared before you call this method, by first calling `SignIn.prepareSecondFactor`. Depending on the strategy that was selected when the verification was prepared, the method parameters should be different.
  ///
  /// The `totp` strategy can directly be attempted, without the need for preparation.
  ///
  /// - Parameters:
  ///   - strategy: An enum that defines the strategy for second factor verification. See ``SignIn/AttemptSecondFactorStrategy`` for available strategies.
  ///
  /// - Returns: A `SignIn` object. Check the `secondFactorVerification` attribute for the status of the second factor verification process.
  ///
  /// - Throws: An error if the second factor verification fails.
  @discardableResult @MainActor
  public func attemptSecondFactor(strategy: AttemptSecondFactorStrategy) async throws -> SignIn {
    try await signInService.attemptSecondFactor(signInId: id, strategy: strategy)
  }

  #if !os(tvOS) && !os(watchOS)
  /// Creates a new ``SignIn`` and initiates an external authentication flow using a redirect-based strategy.
  ///
  /// This function handles the process of creating a ``SignIn`` instance,
  /// starting an external web authentication session, and processing the callback URL upon successful
  /// authentication.
  ///
  /// - Parameters:
  ///   - strategy: The authentication strategy to use for the external authentication flow.
  ///               See ``SignIn/AuthenticateWithRedirectStrategy`` for available options.
  ///   - prefersEphemeralWebBrowserSession: A Boolean indicating whether to prefer an ephemeral web
  ///                                         browser session (default is `false`). When `true`, the session
  ///                                         does not persist cookies or other data between sessions, ensuring
  ///                                         a private browsing experience.
  ///
  /// - Throws: An error of type ``ClerkClientError`` if the redirect URL is missing or invalid, or any errors
  ///           encountered during the sign-in or authentication processes.
  ///
  /// - Returns: ``TransferFlowResult`` object containing the result of the external authentication flow which can be either a ``SignIn`` or ``SignUp``.
  ///
  /// Example:
  /// ```swift
  /// let result = try await SignIn.authenticateWithRedirect(strategy: .oauth(provider: .google))
  /// ```
  @discardableResult @MainActor
  public static func authenticateWithRedirect(strategy: SignIn.AuthenticateWithRedirectStrategy, prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    try await Self.signInService.authenticateWithRedirectStatic(strategy: strategy, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
  }
  #endif

  #if !os(tvOS) && !os(watchOS)
  /// Initiates an external authentication flow using a redirect-based strategy for the current ``SignIn`` instance.
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
  ///            which can be either a ``SignIn`` or ``SignUp``.
  ///
  /// Example:
  /// ```swift
  /// let signIn = try await SignIn.create(strategy: .oauth(provider: .google))
  /// let result = try await signIn.authenticateWithRedirect()
  /// ```
  @discardableResult @MainActor
  public func authenticateWithRedirect(prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    try await signInService.authenticateWithRedirect(signIn: self, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
  }

  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Presents the system sheet to allow the user to sign in using their passkey.
  ///
  /// This method handles the process of requesting a credential for passkey-based authentication by interacting with the
  /// platform's authentication services. It supports both autofill-assisted flows and standard credential selection flows,
  /// allowing for a seamless user experience.
  ///
  /// - Parameters:
  ///   - autofill: A Boolean indicating whether to use an autofill-assisted flow (default is `false`).
  ///   - preferImmediatelyAvailableCredentials: Tells the authorization controller to prefer credentials that are immediately available on the local device (default is `true`).
  ///
  /// - Throws: ``ClerkClientError``
  ///
  /// - Returns: A `String` containing the passkey credential as a JSON-encoded string. This includes the necessary
  ///            information for verifying the user's identity with the public key credential response.
  ///
  /// Example:
  /// ```swift
  /// let signIn = try await SignIn.create(strategy: .passkey)
  /// let credential = try await signIn.getCredentialForPasskey()
  /// ```
  ///
  /// - Note: This method uses `ASAuthorizationPlatformPublicKeyCredentialAssertion` to retrieve the passkey credentials
  ///         and formats them according to the WebAuthn standard.
  @MainActor
  public func getCredentialForPasskey(autofill: Bool = false, preferImmediatelyAvailableCredentials: Bool = true) async throws -> String {
    try await signInService.getCredentialForPasskey(signIn: self, autofill: autofill, preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials)
  }
  #endif

  /// Authenticates the user using an ID Token and a specified provider.
  ///
  /// This method facilitates authentication using an ID token provided by a specific authentication provider.
  /// It determines whether the user needs to be transferred to a sign-up flow.
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
  /// let result = try await SignIn.authenticateWithIdToken(
  ///     provider: .apple,
  ///     idToken: idToken
  /// )
  /// ```
  @discardableResult @MainActor
  public static func authenticateWithIdToken(provider: IDTokenProvider, idToken: String) async throws -> TransferFlowResult {
    try await Self.signInService.authenticateWithIdTokenStatic(provider: provider, idToken: idToken)
  }

  /// Authenticates the user using an ID Token and a specified provider.
  ///
  /// This method completes authentication using an ID token provided by a specific authentication provider.
  /// It determines whether the user needs to be transferred to a sign-up flow.
  ///
  /// - Throws:``ClerkClientError``
  ///
  /// - Returns: ``TransferFlowResult`` containing either a sign-in or a newly created sign-up instance.
  ///
  /// ### Example
  /// ```swift
  /// let signIn = try await SignIn.create(strategy: .idToken(provider: .apple, idToken: "idToken"))
  /// let result = try await signIn.authenticateWithIdToken()
  /// ```
  @discardableResult @MainActor
  public func authenticateWithIdToken() async throws -> TransferFlowResult {
    try await signInService.authenticateWithIdToken(signIn: self)
  }

  /// Returns the current sign-in.
  @discardableResult @MainActor
  public func get(rotatingTokenNonce: String? = nil) async throws -> SignIn {
    try await signInService.get(signInId: id, rotatingTokenNonce: rotatingTokenNonce)
  }
}

extension SignIn {

  // MARK: - Internal Helpers

  /// Handles the callback url from external authentication. Determines whether to return a sign in or sign up.
  @discardableResult @MainActor
  func handleOAuthCallbackUrl(_ url: URL) async throws -> TransferFlowResult {
    if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
      let updatedSignIn = try await get(rotatingTokenNonce: nonce)
      return .signIn(updatedSignIn)
    } else {
      // transfer flow
      let signIn = try await get()
      let result = try await signIn.handleTransferFlow()
      return result
    }
  }

  /// Determines whether or not to return a sign in or sign up object as part of the transfer flow.
  func handleTransferFlow() async throws -> TransferFlowResult {
    if needsTransferToSignUp == true {
      let signUp = try await SignUp.create(strategy: .transfer)
      return .signUp(signUp)
    } else {
      return .signIn(self)
    }
  }

  /// Helper to determine if the SignIn needs to be transferred to a SignUp
  var needsTransferToSignUp: Bool {
    firstFactorVerification?.status == .transferable || secondFactorVerification?.status == .transferable
  }

  /// The first factor for the identifier that was used to initiate the SignIn
  package func identifyingFirstFactor(strategy: PrepareFirstFactorStrategy) -> Factor? {
    supportedFirstFactors?.first(where: { factor in
      factor.strategy == strategy.strategy && factor.safeIdentifier == identifier
    })
  }

  /// The second factor matching the specified strategy.
  func identifyingSecondFactor(strategy: PrepareSecondFactorStrategy) -> Factor? {
    supportedSecondFactors?.first(where: { factor in
      factor.strategy == strategy.strategy && factor.safeIdentifier == identifier
    })
  }

}

extension SignIn {

  package static var mock: SignIn {
    SignIn(
      id: "1",
      status: .needsIdentifier,
      supportedIdentifiers: [.emailAddress, .phoneNumber],
      identifier: User.mock.emailAddresses.first?.emailAddress,
      supportedFirstFactors: [
        .mockEmailCode,
        .mockPhoneCode,
        .mockGoogle,
        .mockApple,
        .mockPasskey,
        .mockPassword
      ],
      supportedSecondFactors: nil,
      firstFactorVerification: .mockEmailCodeUnverifiedVerification,
      secondFactorVerification: nil,
      userData: nil,
      createdSessionId: nil
    )
  }

}
