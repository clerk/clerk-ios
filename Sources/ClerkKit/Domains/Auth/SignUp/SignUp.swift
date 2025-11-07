//
//  SignUp.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import AuthenticationServices
import Foundation

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
  public var id: String

  /// The status of the current sign-up.
  ///
  /// See ``SignUp/Status-swift.enum`` for supported values.
  public var status: Status

  /// An array of all the required fields that need to be supplied and verified in order for this sign-up to be marked as complete and converted into a user.
  public var requiredFields: [String]

  /// An array of all the fields that can be supplied to the sign-up, but their absence does not prevent the sign-up from being marked as complete.
  public var optionalFields: [String]

  /// An array of all the fields whose values are not supplied yet but they are mandatory in order for a sign-up to be marked as complete.
  public var missingFields: [String]

  /// An array of all the fields whose values have been supplied, but they need additional verification in order for them to be accepted.
  ///
  /// Examples of such fields are `email_address` and `phone_number`.
  public var unverifiedFields: [String]

  /// An object that contains information about all the verifications that are in-flight.
  public var verifications: [String: Verification?]

  /// The username supplied to the current sign-up. Only supported if username is enabled in the instance settings.
  public var username: String?

  /// The email address supplied to the current sign-up. Only supported if email address is enabled in the instance settings.
  public var emailAddress: String?

  /// The user's phone number in E.164 format. Only supported if phone number is enabled in the instance settings.
  public var phoneNumber: String?

  /// The Web3 wallet address, made up of 0x + 40 hexadecimal characters. Only supported if Web3 authentication is enabled in the instance settings.
  public var web3Wallet: String?

  /// The value of this attribute is true if a password was supplied to the current sign-up. Only supported if password is enabled in the instance settings.
  public var passwordEnabled: Bool

  /// The first name supplied to the current sign-up. Only supported if name is enabled in the instance settings.
  public var firstName: String?

  /// The last name supplied to the current sign-up. Only supported if name is enabled in the instance settings.
  public var lastName: String?

  /// Metadata that can be read and set from the frontend. Once the sign-up is complete, the value of this field will be automatically copied to the newly created user's unsafe metadata. One common use case for this attribute is to use it to implement custom fields that can be collected during sign-up and will automatically be attached to the created User object.
  public var unsafeMetadata: JSON?

  /// The identifier of the newly-created session. This attribute is populated only when the sign-up is complete.
  public var createdSessionId: String?

  /// The identifier of the newly-created user. This attribute is populated only when the sign-up is complete.
  public var createdUserId: String?

  /// The date when the sign-up was abandoned by the user.
  public var abandonAt: Date

  public init(
    id: String,
    status: SignUp.Status,
    requiredFields: [String],
    optionalFields: [String],
    missingFields: [String],
    unverifiedFields: [String],
    verifications: [String: Verification?],
    username: String? = nil,
    emailAddress: String? = nil,
    phoneNumber: String? = nil,
    web3Wallet: String? = nil,
    passwordEnabled: Bool,
    firstName: String? = nil,
    lastName: String? = nil,
    unsafeMetadata: JSON? = nil,
    createdSessionId: String? = nil,
    createdUserId: String? = nil,
    abandonAt: Date
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
    self.createdSessionId = createdSessionId
    self.createdUserId = createdUserId
    self.abandonAt = abandonAt
  }
}

public extension SignUp {
  @MainActor
  private static var signUpService: any SignUpServiceProtocol { Clerk.shared.dependencies.signUpService }

  @MainActor
  private var signUpService: any SignUpServiceProtocol { Clerk.shared.dependencies.signUpService }

  /// Initiates a new sign-up process and returns a `SignUp` object based on the provided strategy and optional parameters.
  ///
  /// This method initiates a new sign-up process by sending the appropriate parameters to Clerk's API.
  /// It deactivates any existing sign-up process and stores the sign-up lifecycle state in the `status` property of the new `SignUp` object.
  /// If required fields are provided, the sign-up process can be completed in one step. If not, Clerk's flexible sign-up process allows multi-step flows.
  ///
  /// What you must pass to params depends on which sign-up options you have enabled in your Clerk application instance.
  ///
  /// - Parameters:
  ///   - strategy: The strategy to use for creating the sign-up. This defines the parameters used for the sign-up process. See ``SignUp/CreateStrategy`` for available strategies.
  ///   - legalAccepted: A Boolean value indicating whether the user has accepted the legal terms.
  ///   - locale: Override for the locale sent to the backend (defaults to the device locale when omitted).
  ///
  /// - Returns: A `SignUp` object containing the current status and details of the sign-up process. The `status` property reflects the current state of the sign-up.
  ///
  /// ### Example Usage:
  /// ```swift
  /// let signUp = try await SignUp.create(strategy: .standard(emailAddress: "user@email.com", password: "••••••••"))
  /// ```
  @discardableResult @MainActor
  static func create(strategy: SignUp.CreateStrategy, legalAccepted: Bool? = nil, locale: String? = nil) async throws -> SignUp {
    try await signUpService.create(strategy: strategy, legalAccepted: legalAccepted, locale: locale)
  }

  /// Initiates a new sign-up process and returns a `SignUp` object based on the provided strategy and optional parameters.
  ///
  /// This method initiates a new sign-up process by sending the appropriate parameters to Clerk's API.
  /// It deactivates any existing sign-up process and stores the sign-up lifecycle state in the `status` property of the new `SignUp` object.
  /// If required fields are provided, the sign-up process can be completed in one step. If not, Clerk's flexible sign-up process allows multi-step flows.
  ///
  /// What you must pass to params depends on which sign-up options you have enabled in your Clerk application instance.
  ///
  /// - Parameters:
  ///   - params: A dictionary of parameters used to create the sign-up.
  ///
  /// - Returns: A `SignUp` object containing the current status and details of the sign-up process. The `status` property reflects the current state of the sign-up.
  ///
  /// ### Example Usage:
  /// ```swift
  /// let signUp = try await SignUp.create(["email_address": "user@email.com", "password": "••••••••"])
  /// ```
  @discardableResult @MainActor
  static func create(_ params: some Encodable & Sendable) async throws -> SignUp {
    try await signUpService.createWithParams(params: params)
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
  func update(params: UpdateParams) async throws -> SignUp {
    try await signUpService.update(signUpId: id, params: params)
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
  func prepareVerification(strategy: PrepareStrategy) async throws -> SignUp {
    try await signUpService.prepareVerification(signUpId: id, strategy: strategy)
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
  func attemptVerification(strategy: AttemptStrategy) async throws -> SignUp {
    try await signUpService.attemptVerification(signUpId: id, strategy: strategy)
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
  static func authenticateWithRedirect(strategy: SignUp.AuthenticateWithRedirectStrategy, prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    try await signUpService.authenticateWithRedirect(strategy: strategy, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
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
  func authenticateWithRedirect(prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    try await signUpService.authenticateWithRedirect(signUp: self, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
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
  ///   - firstName: The user's first name (optional). Typically extracted from the provider's credential.
  ///   - lastName: The user's last name (optional). Typically extracted from the provider's credential.
  ///
  /// - Throws:``ClerkClientError``
  ///
  /// - Returns: An ``TransferFlowResult`` containing either a sign-in or a newly created sign-up instance.
  ///
  /// ### Example
  /// ```swift
  /// let result = try await SignUp.authenticateWithIdToken(
  ///     provider: .apple,
  ///     idToken: idToken,
  ///     firstName: firstName,
  ///     lastName: lastName
  /// )
  /// ```
  @discardableResult @MainActor
  static func authenticateWithIdToken(provider: IDTokenProvider, idToken: String, firstName: String? = nil, lastName: String? = nil) async throws -> TransferFlowResult {
    try await signUpService.authenticateWithIdToken(provider: provider, idToken: idToken, firstName: firstName, lastName: lastName)
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
  func authenticateWithIdToken() async throws -> TransferFlowResult {
    try await signUpService.authenticateWithIdToken(signUp: self)
  }
}

extension SignUp {
  // MARK: - Internal Helpers

  private var needsTransferToSignIn: Bool {
    verifications.contains(where: { $0.key == "external_account" && $0.value?.status == .transferable })
  }

  /// Determines whether or not to return a sign in or sign up object as part of the transfer flow.
  func handleTransferFlow() async throws -> TransferFlowResult {
    if needsTransferToSignIn == true {
      let signIn = try await SignIn.create(strategy: .transfer)
      return .signIn(signIn)
    } else {
      return .signUp(self)
    }
  }

  @discardableResult @MainActor
  func handleOAuthCallbackUrl(_ url: URL) async throws -> TransferFlowResult {
    if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
      let updatedSignUp = try await get(rotatingTokenNonce: nonce)
      return .signUp(updatedSignUp)
    } else {
      // transfer flow
      let signUp = try await get()
      let result = try await signUp.handleTransferFlow()
      return result
    }
  }

  /// Returns the current sign up.
  @discardableResult @MainActor
  func get(rotatingTokenNonce: String? = nil) async throws -> SignUp {
    try await signUpService.get(signUpId: id, rotatingTokenNonce: rotatingTokenNonce)
  }
}
