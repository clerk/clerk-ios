//
//  Auth.swift
//  Clerk
//

import AuthenticationServices
import Foundation

/// The main entry point for all authentication operations in the Clerk SDK.
///
/// Access this via `clerk.auth` to perform sign in, sign up, and session management operations.
/// This is a lightweight facade that namespaces auth-related methods - it holds no state itself.
@MainActor
public struct Auth {
  let clerk: Clerk
  let signInService: SignInServiceProtocol
  let signUpService: SignUpServiceProtocol
  let sessionService: SessionServiceProtocol
  let sessionTokenFetcher: SessionTokenFetcher
  let eventEmitter: EventEmitter<AuthEvent>

  /// The current sign-in attempt, if any.
  ///
  /// This mirrors the in-progress `SignIn` stored on the current client.
  /// Useful for continuing identifier-first flows or multi-step verifications.
  ///
  /// ```swift
  /// if let signIn = clerk.auth.currentSignIn {
  ///   // Continue the flow with the existing SignIn instance
  ///   _ = try await signIn.sendEmailCode()
  /// }
  /// ```
  public var currentSignIn: SignIn? {
    clerk.client?.signIn
  }

  /// The current sign-up attempt, if any.
  ///
  /// This mirrors the in-progress `SignUp` stored on the current client.
  ///
  /// ```swift
  /// if let signUp = clerk.auth.currentSignUp {
  ///   // Continue the flow with the existing SignUp instance
  ///   _ = try await signUp.sendEmailCode()
  /// }
  /// ```
  public var currentSignUp: SignUp? {
    clerk.client?.signUp
  }

  /// The sessions on the current client.
  public var sessions: [Session] {
    clerk.client?.sessions ?? []
  }

  /// An `AsyncStream` of authentication events.
  ///
  /// Subscribe to this stream to receive notifications about sign-in completion, sign-up completion,
  /// sign-out, session changes, and token refreshes.
  ///
  /// ### Example:
  /// ```swift
  /// Task {
  ///     for await event in clerk.auth.events {
  ///         switch event {
  ///         case .signInCompleted(let signIn):
  ///             print("Sign in completed: \(signIn)")
  ///         case .signUpCompleted(let signUp):
  ///             print("Sign up completed: \(signUp)")
  ///         case .signedOut(let session):
  ///             print("Signed out: \(session)")
  ///         case .accountDeleted:
  ///             print("Account deleted")
  ///         case .sessionChanged(let oldValue, let newValue):
  ///             print("Session changed from \(oldValue?.id ?? "nil") to \(newValue?.id ?? "nil")")
  ///         case .tokenRefreshed(let token):
  ///             print("Token refreshed: \(token)")
  ///         }
  ///     }
  /// }
  /// ```
  public var events: AsyncStream<AuthEvent> {
    eventEmitter.events
  }

  /// Sends an auth event.
  ///
  /// This is internal to allow middleware to emit events while keeping the emitter private.
  func send(_ event: AuthEvent) {
    eventEmitter.send(event)
  }
}

// MARK: - Sign In

extension Auth {
  /// Creates a new sign-in attempt with the provided identifier.
  ///
  /// The identifier can be an email address, phone number, or username.
  /// Returns a `SignIn` object to determine the next step in the authentication flow.
  ///
  /// - Parameter identifier: The user's email address, phone number, or username.
  /// - Returns: A `SignIn` object representing the sign-in attempt.
  /// - Throws: An error if the sign-in creation fails.
  @discardableResult
  public func signIn(_ identifier: String) async throws -> SignIn {
    try await signInService.create(params: .init(identifier: identifier))
  }

  /// Signs in with an identifier and password.
  ///
  /// - Parameters:
  ///   - identifier: The user's email address, phone number, or username.
  ///   - password: The user's password.
  /// - Returns: A `SignIn` object representing the sign-in attempt.
  /// - Throws: An error if the sign-in fails.
  @discardableResult
  public func signInWithPassword(identifier: String, password: String) async throws -> SignIn {
    try await signInService.create(params: .init(identifier: identifier, password: password))
  }

  /// Signs in with OTP (One-Time Password) using an email address.
  ///
  /// This method creates a sign-in attempt and automatically sends a verification code to the email address.
  ///
  /// - Parameter emailAddress: The user's email address.
  /// - Returns: A `SignIn` object with the first factor verification prepared.
  /// - Throws: An error if the sign-in creation or code sending fails.
  @discardableResult
  public func signInWithEmailCode(emailAddress: String) async throws -> SignIn {
    try await signInService.create(params: .init(identifier: emailAddress, strategy: .emailCode))
  }

  /// Signs in with OTP (One-Time Password) using a phone number.
  ///
  /// This method creates a sign-in attempt and automatically sends a verification code to the phone number.
  ///
  /// - Parameter phoneNumber: The user's phone number in E.164 format.
  /// - Returns: A `SignIn` object with the first factor verification prepared.
  /// - Throws: An error if the sign-in creation or code sending fails.
  @discardableResult
  public func signInWithPhoneCode(phoneNumber: String) async throws -> SignIn {
    try await signInService.create(params: .init(identifier: phoneNumber, strategy: .phoneCode))
  }

  #if !os(tvOS) && !os(watchOS)
  /// Signs in with OAuth using the specified provider.
  ///
  /// - Parameters:
  ///   - provider: The OAuth provider to use (e.g., `.google`, `.apple`).
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the OAuth flow fails.
  @discardableResult
  public func signInWithOAuth(
    provider: OAuthProvider,
    prefersEphemeralWebBrowserSession: Bool = false,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    let signIn = try await signInService.create(params: .init(
      strategy: .oauth(provider),
      redirectUrl: clerk.options.redirectConfig.redirectUrl
    ))
    return try await authenticateWithOAuth(
      for: signIn,
      provider: provider,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
      transferable: transferable
    )
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Signs in with an ID token from a provider (e.g., Sign in with Apple).
  ///
  /// - Parameters:
  ///   - idToken: The ID token from the provider.
  ///   - provider: The ID token provider (e.g., `.apple`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  @discardableResult
  public func signInWithIdToken(_ idToken: String, provider: IDTokenProvider, transferable: Bool = true) async throws -> TransferFlowResult {
    let signIn = try await signInService.create(params: .init(strategy: .idToken(provider), token: idToken))
    let result = try await handleTransferFlow(for: signIn, transferable: transferable)
    if case .signIn(let signIn) = result, let error = signIn.firstFactorVerification?.error {
      throw error
    }
    return result
  }
  #endif

  #if !os(watchOS) && !os(tvOS)
  /// Signs in with Apple using Sign in with Apple.
  ///
  /// This method handles the entire Sign in with Apple flow, including:
  /// - Requesting Apple ID credentials
  /// - Extracting the ID token
  /// - Automatically routing to sign-in or sign-up via the transfer flow
  ///
  /// - Parameters:
  ///   - requestedScopes: The scopes to request from Apple (defaults to `[.email, .fullName]`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  @discardableResult
  public func signInWithApple(
    requestedScopes: [ASAuthorization.Scope] = [.email, .fullName],
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    let requestedScopes = Self.normalizedAppleScopes(
      requestedScopes,
      environment: clerk.environment
    )
    let credential = try await SignInWithAppleHelper.getAppleIdCredential(requestedScopes: requestedScopes)

    guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
      throw ClerkClientError(message: "Unable to retrieve the Apple identity token.")
    }

    if transferable {
      return try await signUpWithIdToken(
        idToken,
        provider: .apple,
        firstName: credential.fullName?.givenName,
        lastName: credential.fullName?.familyName
      )
    } else {
      let signIn = try await signInService.create(params: .init(strategy: .idToken(.apple), token: idToken))
      let result = try await handleTransferFlow(for: signIn, transferable: transferable)
      if case .signIn(let signIn) = result, let error = signIn.firstFactorVerification?.error {
        throw error
      }
      return result
    }
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  static func normalizedAppleScopes(
    _ requestedScopes: [ASAuthorization.Scope],
    environment: Clerk.Environment?
  ) -> [ASAuthorization.Scope] {
    guard requestedScopes.contains(.fullName) else {
      return requestedScopes
    }

    let attributes = environment?.userSettings.attributes
    let firstNameEnabled = attributes?["first_name"]?.enabled ?? true
    let lastNameEnabled = attributes?["last_name"]?.enabled ?? true

    return firstNameEnabled || lastNameEnabled
      ? requestedScopes
      : requestedScopes.filter { $0 != .fullName }
  }
  #endif

  // Signs in with a passkey.
  //
  // - Returns: A `SignIn` object representing the sign-in attempt.
  // - Throws: An error if the passkey sign-in fails.
  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @discardableResult
  public func signInWithPasskey() async throws -> SignIn {
    let signIn = try await signInService.create(params: .init(strategy: .passkey))
    return try await authenticateWithPasskey(for: signIn)
  }
  #endif

  #if !os(tvOS) && !os(watchOS)
  /// Starts Enterprise SSO and returns the prepared sign-in state.
  ///
  /// Use this when your app needs to control how the external verification URL is opened,
  /// such as launching the user's default browser. After this returns, read
  /// ``Verification/externalVerificationRedirectUrl`` from
  /// ``SignIn/firstFactorVerification`` to obtain the URL to open, then complete the flow
  /// with ``SignIn/completeEnterpriseSSO(callbackURL:transferable:)`` after your app
  /// receives the callback URL.
  ///
  /// - Parameters:
  ///   - emailAddress: The user's enterprise email address.
  ///   - redirectUrl: Optional callback URL to override the global Clerk redirect configuration.
  /// - Returns: A prepared `SignIn` object configured for Enterprise SSO.
  /// - Throws: An error if creating or preparing the Enterprise SSO sign-in fails.
  @discardableResult
  public func startEnterpriseSSO(
    emailAddress: String,
    redirectUrl: String? = nil
  ) async throws -> SignIn {
    let redirectUrl = redirectUrl ?? clerk.options.redirectConfig.redirectUrl
    let signIn = try await signInService.create(params: .init(
      identifier: emailAddress,
      strategy: .enterpriseSSO,
      redirectUrl: redirectUrl
    ))
    return try await signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(
        strategy: .enterpriseSSO,
        redirectUrl: redirectUrl
      )
    )
  }

  /// Signs in with Enterprise SSO using an email address.
  ///
  /// This method creates an Enterprise SSO sign-in attempt and then completes the browser-based
  /// authentication flow using the SDK-managed web authentication session.
  ///
  /// - Parameters:
  ///   - emailAddress: The user's enterprise email address.
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the Enterprise SSO flow fails.
  @discardableResult
  public func signInWithEnterpriseSSO(
    emailAddress: String,
    prefersEphemeralWebBrowserSession: Bool = false,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    let signIn = try await signInService.create(params: .init(
      identifier: emailAddress,
      strategy: .enterpriseSSO,
      redirectUrl: clerk.options.redirectConfig.redirectUrl
    ))
    return try await authenticateWithEnterpriseSSO(
      for: signIn,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
      transferable: transferable
    )
  }
  #endif

  /// Signs in with a ticket generated from the Backend API.
  ///
  /// - Parameter ticket: The ticket string from the Backend API.
  /// - Returns: A `SignIn` object representing the sign-in attempt.
  /// - Throws: An error if the ticket sign-in fails.
  @discardableResult
  public func signInWithTicket(_ ticket: String) async throws -> SignIn {
    try await signInService.create(params: .init(
      strategy: .ticket,
      ticket: ticket
    ))
  }

  /// Sends a first-factor email code for an existing sign-in attempt.
  @discardableResult
  func sendEmailCode(for signIn: SignIn, emailAddressId: String? = nil) async throws -> SignIn {
    let emailId = emailAddressId ?? signIn.identifyingFirstFactor(for: "email_code")?.emailAddressId
    return try await signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .emailCode, emailAddressId: emailId)
    )
  }

  /// Sends a first-factor phone code for an existing sign-in attempt.
  @discardableResult
  func sendPhoneCode(for signIn: SignIn, phoneNumberId: String? = nil) async throws -> SignIn {
    let phoneId = phoneNumberId ?? signIn.identifyingFirstFactor(for: "phone_code")?.phoneNumberId
    return try await signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .phoneCode, phoneNumberId: phoneId)
    )
  }

  /// Verifies a first-factor code for an existing sign-in attempt.
  @discardableResult
  func verifyCode(_ code: String, for signIn: SignIn) async throws -> SignIn {
    guard let resolvedStrategy = signIn.firstFactorVerification?.strategy else {
      throw ClerkClientError(message: "Unable to verify code because no first factor strategy is set.")
    }

    guard resolvedStrategy.canAttemptFirstFactorCode else {
      throw ClerkClientError(
        message: "Unable to verify code for strategy '\(resolvedStrategy.rawValue)'."
      )
    }

    return try await signInService.attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: resolvedStrategy, code: code)
    )
  }

  /// Attempts password authentication for an existing sign-in.
  @discardableResult
  func authenticateWithPassword(_ password: String, for signIn: SignIn) async throws -> SignIn {
    try await signInService.attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .password, password: password)
    )
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Attempts ID token authentication for an existing sign-in.
  @discardableResult
  func authenticateWithIdToken(_ idToken: String, provider: IDTokenProvider, for signIn: SignIn) async throws -> SignIn {
    try await signInService.attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .idToken(provider), token: idToken)
    )
  }

  /// Continues an existing sign-in with Sign in with Apple.
  @discardableResult
  func authenticateWithApple(
    for signIn: SignIn,
    requestedScopes: [ASAuthorization.Scope] = [.email, .fullName],
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    let credential = try await SignInWithAppleHelper.getAppleIdCredential(requestedScopes: requestedScopes)

    guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
      throw ClerkClientError(message: "Unable to retrieve the Apple identity token.")
    }

    let updatedSignIn = try await authenticateWithIdToken(idToken, provider: .apple, for: signIn)
    let result = try await handleTransferFlow(for: updatedSignIn, transferable: transferable)
    if case .signIn(let signIn) = result, let error = signIn.firstFactorVerification?.error {
      throw error
    }
    return result
  }
  #endif

  /// Sends an MFA phone code for an existing sign-in.
  @discardableResult
  func sendMfaPhoneCode(for signIn: SignIn, phoneNumberId: String? = nil) async throws -> SignIn {
    let phoneId = phoneNumberId ?? signIn.identifyingSecondFactor(for: "phone_code")?.phoneNumberId
    return try await signInService.prepareSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: .phoneCode, phoneNumberId: phoneId)
    )
  }

  /// Sends an MFA email code for an existing sign-in.
  @discardableResult
  func sendMfaEmailCode(for signIn: SignIn, emailAddressId: String? = nil) async throws -> SignIn {
    let emailId = emailAddressId ?? signIn.identifyingSecondFactor(for: "email_code")?.emailAddressId
    return try await signInService.prepareSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: .emailCode, emailAddressId: emailId)
    )
  }

  /// Verifies an MFA code for an existing sign-in.
  @discardableResult
  func verifyMfaCode(_ code: String, type: SignIn.MfaType, for signIn: SignIn) async throws -> SignIn {
    try await signInService.attemptSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: type.strategy, code: code)
    )
  }

  /// Sends a password reset email code for an existing sign-in.
  @discardableResult
  func sendResetPasswordEmailCode(for signIn: SignIn, emailAddressId: String? = nil) async throws -> SignIn {
    let emailId = emailAddressId ?? signIn.identifyingFirstFactor(for: "reset_password_email_code")?.emailAddressId
    return try await signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .resetPasswordEmailCode, emailAddressId: emailId)
    )
  }

  /// Sends a password reset phone code for an existing sign-in.
  @discardableResult
  func sendResetPasswordPhoneCode(for signIn: SignIn, phoneNumberId: String? = nil) async throws -> SignIn {
    let phoneId = phoneNumberId ?? signIn.identifyingFirstFactor(for: "reset_password_phone_code")?.phoneNumberId
    return try await signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .resetPasswordPhoneCode, phoneNumberId: phoneId)
    )
  }

  /// Resets the password for an existing sign-in attempt.
  @discardableResult
  func resetPassword(
    for signIn: SignIn,
    newPassword: String,
    signOutOfOtherSessions: Bool = false
  ) async throws -> SignIn {
    try await signInService.resetPassword(
      signInId: signIn.id,
      params: .init(password: newPassword, signOutOfOtherSessions: signOutOfOtherSessions)
    )
  }

  #if !os(tvOS) && !os(watchOS)
  /// Completes an Enterprise SSO callback for an existing sign-in.
  @discardableResult
  func completeEnterpriseSSO(
    for signIn: SignIn,
    callbackURL: URL,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    try await handleRedirectCallbackUrl(callbackURL, for: signIn, transferable: transferable)
  }

  /// Continues an existing sign-in with Enterprise SSO.
  @discardableResult
  func authenticateWithEnterpriseSSO(
    for signIn: SignIn,
    prefersEphemeralWebBrowserSession: Bool = false,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    let preparedSignIn = try await signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(
        strategy: .enterpriseSSO,
        redirectUrl: clerk.options.redirectConfig.redirectUrl
      )
    )

    let url = try externalAuthenticationURL(preparedSignIn.firstFactorVerification?.externalVerificationRedirectUrl)
    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )
    let callbackUrl = try await authSession.start()
    return try await handleRedirectCallbackUrl(callbackUrl, for: preparedSignIn, transferable: transferable)
  }

  /// Continues an existing sign-in with OAuth.
  @discardableResult
  func authenticateWithOAuth(
    for signIn: SignIn,
    provider: OAuthProvider,
    prefersEphemeralWebBrowserSession: Bool = false,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    let preparedSignIn = try await signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(
        strategy: .oauth(provider),
        redirectUrl: clerk.options.redirectConfig.redirectUrl
      )
    )

    let url = try externalAuthenticationURL(preparedSignIn.firstFactorVerification?.externalVerificationRedirectUrl)
    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )
    let callbackUrl = try await authSession.start()
    return try await handleRedirectCallbackUrl(callbackUrl, for: preparedSignIn, transferable: transferable)
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Continues an existing sign-in with a passkey.
  @discardableResult
  func authenticateWithPasskey(
    for signIn: SignIn,
    autofill: Bool = false,
    preferImmediatelyAvailableCredentials: Bool = true
  ) async throws -> SignIn {
    let preparedSignIn = try await signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .passkey, redirectUrl: clerk.options.redirectConfig.redirectUrl)
    )

    let credential = try await getCredentialForPasskey(
      from: preparedSignIn,
      autofill: autofill,
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
    )

    return try await signInService.attemptFirstFactor(
      signInId: preparedSignIn.id,
      params: .init(strategy: .passkey, publicKeyCredential: credential)
    )
  }
  #endif
}

// MARK: - Sign Up

extension Auth {
  /// Creates a new sign-up attempt with the provided parameters.
  ///
  /// - Parameters:
  ///   - emailAddress: The user's email address (optional).
  ///   - password: The user's password (optional).
  ///   - firstName: The user's first name (optional).
  ///   - lastName: The user's last name (optional).
  ///   - username: The user's username (optional).
  ///   - phoneNumber: The user's phone number in E.164 format (optional).
  ///   - unsafeMetadata: Custom metadata to attach to the user (optional).
  ///   - legalAccepted: Whether the user has accepted legal terms (optional).
  /// - Returns: A `SignUp` object representing the sign-up attempt.
  /// - Throws: An error if the sign-up creation fails.
  @discardableResult
  public func signUp(
    emailAddress: String? = nil,
    password: String? = nil,
    firstName: String? = nil,
    lastName: String? = nil,
    username: String? = nil,
    phoneNumber: String? = nil,
    unsafeMetadata: JSON? = nil,
    legalAccepted: Bool? = nil
  ) async throws -> SignUp {
    try await signUpService.create(params: .init(
      emailAddress: emailAddress,
      phoneNumber: phoneNumber,
      password: password,
      firstName: firstName,
      lastName: lastName,
      username: username,
      unsafeMetadata: unsafeMetadata,
      legalAccepted: legalAccepted
    ))
  }

  #if !os(tvOS) && !os(watchOS)
  /// Signs up with OAuth using the specified provider.
  ///
  /// - Parameters:
  ///   - provider: The OAuth provider to use (e.g., `.google`, `.apple`).
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the OAuth flow fails.
  @discardableResult
  public func signUpWithOAuth(
    provider: OAuthProvider,
    prefersEphemeralWebBrowserSession: Bool = false
  ) async throws -> TransferFlowResult {
    let signUp = try await signUpService.create(params: .init(
      strategy: FactorStrategy(rawValue: provider.strategy),
      redirectUrl: clerk.options.redirectConfig.redirectUrl
    ))

    let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value
    let url = try externalAuthenticationURL(verification?.externalVerificationRedirectUrl)
    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )
    let callbackUrl = try await authSession.start()
    return try await handleRedirectCallbackUrl(callbackUrl, for: signUp)
  }
  #endif

  #if !os(watchOS) && !os(tvOS)
  /// Signs up with Apple using Sign in with Apple.
  ///
  /// This method handles the entire Sign in with Apple flow and can return either a sign-in or sign-up result.
  ///
  /// - Parameters:
  ///   - requestedScopes: The scopes to request from Apple (defaults to `[.email, .fullName]`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  @discardableResult
  public func signUpWithApple(requestedScopes: [ASAuthorization.Scope] = [.email, .fullName]) async throws -> TransferFlowResult {
    try await signInWithApple(requestedScopes: requestedScopes)
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Signs up with an ID token from a provider (e.g., Sign in with Apple).
  ///
  /// - Parameters:
  ///   - idToken: The ID token from the provider.
  ///   - provider: The ID token provider (e.g., `.apple`).
  ///   - firstName: The user's first name (optional).
  ///   - lastName: The user's last name (optional).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  @discardableResult
  public func signUpWithIdToken(
    _ idToken: String,
    provider: IDTokenProvider,
    firstName: String? = nil,
    lastName: String? = nil
  ) async throws -> TransferFlowResult {
    let signUp = try await signUpService.create(params: .init(
      firstName: firstName,
      lastName: lastName,
      strategy: FactorStrategy(rawValue: provider.strategy),
      token: idToken
    ))
    return try await handleTransferFlow(for: signUp)
  }
  #endif

  #if !os(tvOS) && !os(watchOS)
  /// Signs up with Enterprise SSO using an email address.
  ///
  /// - Parameters:
  ///   - emailAddress: The user's enterprise email address.
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the Enterprise SSO flow fails.
  @discardableResult
  public func signUpWithEnterpriseSSO(
    emailAddress: String,
    prefersEphemeralWebBrowserSession: Bool = false
  ) async throws -> TransferFlowResult {
    let signUp = try await signUpService.create(params: .init(
      emailAddress: emailAddress,
      strategy: .enterpriseSSO,
      redirectUrl: clerk.options.redirectConfig.redirectUrl
    ))

    let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value
    let url = try externalAuthenticationURL(verification?.externalVerificationRedirectUrl)
    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )
    let callbackUrl = try await authSession.start()
    return try await handleRedirectCallbackUrl(callbackUrl, for: signUp)
  }
  #endif

  /// Signs up with a ticket generated from the Backend API.
  ///
  /// - Parameter ticket: The ticket string from the Backend API.
  /// - Returns: A `SignUp` object representing the sign-up attempt.
  /// - Throws: An error if the ticket sign-up fails.
  @discardableResult
  public func signUpWithTicket(_ ticket: String) async throws -> SignUp {
    try await signUpService.create(params: .init(
      ticket: ticket,
      strategy: .ticket
    ))
  }

  @discardableResult
  func update(
    _ signUp: SignUp,
    emailAddress: String? = nil,
    password: String? = nil,
    firstName: String? = nil,
    lastName: String? = nil,
    username: String? = nil,
    phoneNumber: String? = nil,
    unsafeMetadata: JSON? = nil,
    legalAccepted: Bool? = nil
  ) async throws -> SignUp {
    try await signUpService.update(signUpId: signUp.id, params: .init(
      emailAddress: emailAddress,
      phoneNumber: phoneNumber,
      password: password,
      firstName: firstName,
      lastName: lastName,
      username: username,
      unsafeMetadata: unsafeMetadata,
      legalAccepted: legalAccepted
    ))
  }

  @discardableResult
  func sendEmailCode(for signUp: SignUp) async throws -> SignUp {
    try await signUpService.prepareVerification(
      signUpId: signUp.id,
      params: .init(strategy: .emailCode, emailAddressId: nil)
    )
  }

  @discardableResult
  func sendPhoneCode(for signUp: SignUp) async throws -> SignUp {
    try await signUpService.prepareVerification(
      signUpId: signUp.id,
      params: .init(strategy: .phoneCode, phoneNumberId: nil)
    )
  }

  @discardableResult
  func verifyEmailCode(_ code: String, for signUp: SignUp) async throws -> SignUp {
    try await signUpService.attemptVerification(
      signUpId: signUp.id,
      params: .init(strategy: .emailCode, code: code)
    )
  }

  @discardableResult
  func verifyPhoneCode(_ code: String, for signUp: SignUp) async throws -> SignUp {
    try await signUpService.attemptVerification(
      signUpId: signUp.id,
      params: .init(strategy: .phoneCode, code: code)
    )
  }
}

// MARK: - Sessions

extension Auth {
  /// Signs out the active user.
  ///
  /// - Parameter sessionId: An optional session ID to sign out from a specific session. If nil, signs out from all sessions.
  /// - Throws: An error if the sign-out process fails.
  public func signOut(sessionId: String? = nil) async throws {
    try await sessionService.signOut(sessionId: sessionId)
  }

  /// Sets the active session and optionally the active organization.
  ///
  /// - Parameters:
  ///   - sessionId: The session ID to set as active.
  ///   - organizationId: The organization ID to set as active in the current session. If nil, removes the active organization.
  /// - Throws: An error if setting the active session fails.
  public func setActive(sessionId: String, organizationId: String? = nil) async throws {
    try await sessionService.setActive(
      sessionId: sessionId,
      organizationId: organizationId
    )
  }

  /// Retrieves the user's session token for the given template or the default Clerk token.
  ///
  /// This method uses a cache so a network request will only be made if the token in memory is expired.
  /// The TTL for Clerk token is one minute.
  ///
  /// - Parameter options: Options for token retrieval. See `Session.GetTokenOptions` for details.
  /// - Returns: The session token string, or nil if no active session exists.
  /// - Throws: An error if token retrieval fails.
  @discardableResult
  public func getToken(_ options: Session.GetTokenOptions = .init()) async throws -> String? {
    guard let session = clerk.session else {
      return nil
    }

    return try await getToken(for: session, options: options)
  }

  /// Revokes the specified session.
  ///
  /// - Parameter session: The session to revoke.
  /// - Returns: The revoked session.
  /// - Throws: An error if revoking the session fails.
  @discardableResult
  public func revokeSession(_ session: Session) async throws -> Session {
    try await sessionService.revoke(
      sessionId: session.id,
      actingSessionId: clerk.session?.id
    )
  }

  @discardableResult
  func revoke(_ session: Session) async throws -> Session {
    try await sessionService.revoke(
      sessionId: session.id,
      actingSessionId: clerk.session?.id
    )
  }

  @discardableResult
  func getToken(
    for session: Session,
    options: Session.GetTokenOptions = .init()
  ) async throws -> String? {
    try await sessionTokenFetcher.getToken(session, options: options)?.jwt
  }
}

// MARK: - Flow Helpers

extension Auth {
  func externalAuthenticationURL(_ redirectUrl: String?) throws -> URL {
    guard let redirectUrl,
          let url = URL(string: redirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
    }

    return url
  }

  @discardableResult
  func reload(_ signIn: SignIn, rotatingTokenNonce: String? = nil) async throws -> SignIn {
    try await signInService.get(signInId: signIn.id, params: .init(rotatingTokenNonce: rotatingTokenNonce))
  }

  @discardableResult
  func handleTransferFlow(
    for signIn: SignIn,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    guard transferable, signIn.needsTransferToSignUp else {
      return .signIn(signIn)
    }

    let signUp = try await signUpService.create(params: .init(transfer: true))
    return .signUp(signUp)
  }

  @discardableResult
  func handleRedirectCallbackUrl(
    _ url: URL,
    for signIn: SignIn,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
      let updatedSignIn = try await reload(signIn, rotatingTokenNonce: nonce)
      if let error = updatedSignIn.firstFactorVerification?.error {
        throw error
      }
      return .signIn(updatedSignIn)
    }

    let updatedSignIn = try await reload(signIn)
    let result = try await handleTransferFlow(for: updatedSignIn, transferable: transferable)

    switch result {
    case .signIn(let signIn):
      if let error = signIn.firstFactorVerification?.error {
        throw error
      }
    case .signUp(let signUp):
      if let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
         let error = verification.error
      {
        throw error
      }
    }

    return result
  }

  @discardableResult
  func reload(_ signUp: SignUp, rotatingTokenNonce: String? = nil) async throws -> SignUp {
    try await signUpService.get(signUpId: signUp.id, params: .init(rotatingTokenNonce: rotatingTokenNonce))
  }

  func handleTransferFlow(for signUp: SignUp) async throws -> TransferFlowResult {
    guard signUp.needsTransferToSignIn else {
      return .signUp(signUp)
    }

    let signIn = try await signInService.create(params: .init(transfer: true))
    return .signIn(signIn)
  }

  @discardableResult
  func handleRedirectCallbackUrl(_ url: URL, for signUp: SignUp) async throws -> TransferFlowResult {
    if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
      let updatedSignUp = try await reload(signUp, rotatingTokenNonce: nonce)
      if let verification = updatedSignUp.verifications.first(where: { $0.key == "external_account" })?.value,
         let error = verification.error
      {
        throw error
      }
      return .signUp(updatedSignUp)
    }

    let updatedSignUp = try await reload(signUp)
    let result = try await handleTransferFlow(for: updatedSignUp)

    switch result {
    case .signIn(let signIn):
      if let error = signIn.firstFactorVerification?.error {
        throw error
      }
    case .signUp(let signUp):
      if let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
         let error = verification.error
      {
        throw error
      }
    }

    return result
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  func getCredentialForPasskey(
    from signIn: SignIn,
    autofill: Bool = false,
    preferImmediatelyAvailableCredentials: Bool = true
  ) async throws -> String {
    guard
      let nonceJSON = signIn.firstFactorVerification?.nonce?.toJSON(),
      let challengeString = nonceJSON["challenge"]?.stringValue,
      let challenge = challengeString.dataFromBase64URL()
    else {
      throw ClerkClientError(message: "Unable to get the challenge for the passkey.")
    }

    let manager = PasskeyHelper()
    let authorization: ASAuthorization

    #if os(iOS) && !targetEnvironment(macCatalyst)
    if autofill {
      authorization = try await manager.beginAutoFillAssistedPasskeySignIn(challenge: challenge)
    } else {
      authorization = try await manager.signIn(
        challenge: challenge,
        preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
      )
    }
    #else
    authorization = try await manager.signIn(
      challenge: challenge,
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
    )
    #endif

    guard
      let credentialAssertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion,
      let authenticatorData = credentialAssertion.rawAuthenticatorData
    else {
      throw ClerkClientError(message: "Invalid credential type.")
    }

    let publicKeyCredential: [String: Any] = [
      "id": credentialAssertion.credentialID.base64EncodedString().base64URLFromBase64String(),
      "rawId": credentialAssertion.credentialID.base64EncodedString().base64URLFromBase64String(),
      "type": "public-key",
      "response": [
        "authenticatorData": authenticatorData.base64EncodedString().base64URLFromBase64String(),
        "clientDataJSON": credentialAssertion.rawClientDataJSON.base64EncodedString().base64URLFromBase64String(),
        "signature": credentialAssertion.signature.base64EncodedString().base64URLFromBase64String(),
        "userHandle": credentialAssertion.userID.base64EncodedString().base64URLFromBase64String(),
      ],
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: publicKeyCredential)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw ClerkClientError(message: "Unable to encode the passkey credential.")
    }

    return jsonString
  }
  #endif
}
