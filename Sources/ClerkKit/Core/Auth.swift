//
//  Auth.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import AuthenticationServices
import Foundation

/// The main entry point for all authentication operations in the Clerk SDK.
///
/// Access this via `clerk.auth` to perform sign in, sign up, and session management operations.
/// This is a lightweight facade that namespaces auth-related methods - it holds no state itself.
@MainActor
public struct Auth {
  private let signInService: SignInServiceProtocol
  private let signUpService: SignUpServiceProtocol
  private let sessionService: SessionServiceProtocol
  private let eventEmitter: EventEmitter<AuthEvent>

  init(
    signInService: SignInServiceProtocol,
    signUpService: SignUpServiceProtocol,
    sessionService: SessionServiceProtocol,
    eventEmitter: EventEmitter<AuthEvent>
  ) {
    self.signInService = signInService
    self.signUpService = signUpService
    self.sessionService = sessionService
    self.eventEmitter = eventEmitter
  }

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
    Clerk.shared.client?.signIn
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
    Clerk.shared.client?.signUp
  }

  // MARK: - Sign In Entry Points

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

  /// Signs in with OAuth using the specified provider.
  ///
  /// - Parameters:
  ///   - provider: The OAuth provider to use (e.g., `.google`, `.apple`).
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the OAuth flow fails.
  #if !os(tvOS) && !os(watchOS)
  @discardableResult
  public func signInWithOAuth(provider: OAuthProvider, prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    // Use the sign-up endpoint to preserve profile details (e.g., names) when available.
    try await signUpWithOAuth(
      provider: provider,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )
  }
  #endif

  /// Signs in with an ID token from a provider (e.g., Sign in with Apple).
  ///
  /// - Parameters:
  ///   - idToken: The ID token from the provider.
  ///   - provider: The ID token provider (e.g., `.apple`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @discardableResult
  public func signInWithIdToken(_ idToken: String, provider: IDTokenProvider) async throws -> TransferFlowResult {
    let signIn = try await signInService.create(params: .init(strategy: .idToken(provider), token: idToken))
    return try await signIn.handleTransferFlow()
  }
  #endif

  /// Signs in with Apple using Sign in with Apple.
  ///
  /// This method handles the entire Sign in with Apple flow, including:
  /// - Requesting Apple ID credentials
  /// - Extracting the ID token
  /// - Automatically routing to sign-in or sign-up via the transfer flow
  ///
  /// - Parameters:
  ///   - requestedScopes: The scopes to request from Apple (defaults to `[.email, .fullName]`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @discardableResult
  public func signInWithApple(requestedScopes: [ASAuthorization.Scope] = [.email, .fullName]) async throws -> TransferFlowResult {
    let credential = try await SignInWithAppleHelper.getAppleIdCredential(requestedScopes: requestedScopes)

    guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
      throw ClerkClientError(message: "Unable to retrieve the Apple identity token.")
    }

    return try await signUpWithIdToken(
      idToken,
      provider: .apple,
      firstName: credential.fullName?.givenName,
      lastName: credential.fullName?.familyName
    )
  }
  #endif

  /// Signs in with a passkey.
  ///
  /// - Returns: A `SignIn` object representing the sign-in attempt.
  /// - Throws: An error if the passkey sign-in fails.
  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @discardableResult
  public func signInWithPasskey() async throws -> SignIn {
    try await signInService.create(params: .init(strategy: .passkey))
  }
  #endif

  /// Signs in with Enterprise SSO using an email address.
  ///
  /// - Parameters:
  ///   - emailAddress: The user's enterprise email address.
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the Enterprise SSO flow fails.
  #if !os(tvOS) && !os(watchOS)
  @discardableResult
  public func signInWithEnterpriseSSO(emailAddress: String, prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    // Use the sign-up endpoint to preserve profile details (e.g., names) when available.
    try await signUpWithEnterpriseSSO(
      emailAddress: emailAddress,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
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

  // MARK: - Sign Up Entry Points

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

  /// Signs up with OAuth using the specified provider.
  ///
  /// - Parameters:
  ///   - provider: The OAuth provider to use (e.g., `.google`, `.apple`).
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the OAuth flow fails.
  #if !os(tvOS) && !os(watchOS)
  @discardableResult
  /// Signs up with Apple using Sign in with Apple.
  ///
  /// This method handles the entire Sign in with Apple flow and can return either a sign-in or sign-up result.
  ///
  /// - Parameters:
  ///   - requestedScopes: The scopes to request from Apple (defaults to `[.email, .fullName]`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @discardableResult
  public func signUpWithApple(requestedScopes: [ASAuthorization.Scope] = [.email, .fullName]) async throws -> TransferFlowResult {
    // Delegate to the sign-in implementation which already handles the transfer flow.
    try await signInWithApple(requestedScopes: requestedScopes)
  }
  #endif

  public func signUpWithOAuth(provider: OAuthProvider, prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    let signUp = try await signUpService.create(params: .init(
      strategy: FactorStrategy(rawValue: provider.strategy),
      redirectUrl: Clerk.shared.options.redirectConfig.redirectUrl
    ))

    guard
      let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
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
    return try await signUp.handleRedirectCallbackUrl(callbackUrl)
  }
  #endif

  /// Signs up with an ID token from a provider (e.g., Sign in with Apple).
  ///
  /// - Parameters:
  ///   - idToken: The ID token from the provider.
  ///   - provider: The ID token provider (e.g., `.apple`).
  ///   - firstName: The user's first name (optional).
  ///   - lastName: The user's last name (optional).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @discardableResult
  public func signUpWithIdToken(_ idToken: String, provider: IDTokenProvider, firstName: String? = nil, lastName: String? = nil) async throws -> TransferFlowResult {
    let signUp = try await signUpService.create(params: .init(
      firstName: firstName,
      lastName: lastName,
      strategy: FactorStrategy(rawValue: provider.strategy),
      token: idToken
    ))
    return try await signUp.handleTransferFlow()
  }
  #endif

  /// Signs up with Enterprise SSO using an email address.
  ///
  /// - Parameters:
  ///   - emailAddress: The user's enterprise email address.
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the Enterprise SSO flow fails.
  #if !os(tvOS) && !os(watchOS)
  @discardableResult
  public func signUpWithEnterpriseSSO(emailAddress: String, prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    let signUp = try await signUpService.create(params: .init(
      emailAddress: emailAddress,
      strategy: .enterpriseSSO,
      redirectUrl: Clerk.shared.options.redirectConfig.redirectUrl
    ))

    guard
      let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
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
    return try await signUp.handleRedirectCallbackUrl(callbackUrl)
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

  // MARK: - Session Management

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
    guard let session = Clerk.shared.session else {
      return nil
    }
    return try await session.getToken(options)?.jwt
  }

  /// Revokes the specified session.
  ///
  /// - Parameter session: The session to revoke.
  /// - Returns: The revoked session.
  /// - Throws: An error if revoking the session fails.
  @discardableResult
  public func revokeSession(_ session: Session) async throws -> Session {
    try await sessionService.revoke(sessionId: session.id)
  }

  // MARK: - Events

  /// An `AsyncStream` of authentication events.
  ///
  /// Subscribe to this stream to receive notifications about sign-in completion, sign-up completion, sign-out, and session changes.
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
  ///         case .sessionChanged(let session):
  ///             print("Session changed: \(session?.id ?? "nil")")
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
