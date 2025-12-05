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
/// Access this class via `clerk.auth` to perform sign in, sign up, and session management operations.
@MainActor
public final class Auth {
  private let signInService: SignInServiceProtocol
  private let signUpService: SignUpServiceProtocol
  private let sessionService: SessionServiceProtocol
  private let clerk: Clerk

  init(
    signInService: SignInServiceProtocol,
    signUpService: SignUpServiceProtocol,
    sessionService: SessionServiceProtocol,
    clerk: Clerk
  ) {
    self.signInService = signInService
    self.signUpService = signUpService
    self.sessionService = sessionService
    self.clerk = clerk
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
    let signIn = try await signInService.create(params: .init(
      strategy: FactorStrategy(rawValue: provider.strategy),
      redirectUrl: clerk.options.redirectConfig.redirectUrl
    ))

    guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl,
          let url = URL(string: externalVerificationRedirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
    }

    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )
    let callbackUrl = try await authSession.start()
    return try await signIn.handleRedirectCallbackUrl(callbackUrl)
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

  /// Signs in with the account portal.
  ///
  /// - Parameter prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the account portal flow fails.
  #if !os(tvOS) && !os(watchOS)
  @discardableResult
  public func signInWithAccountPortal(prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    let signIn = try await signInService.create(params: .init(
      strategy: FactorStrategy(rawValue: "account_portal"),
      redirectUrl: clerk.options.redirectConfig.redirectUrl
    ))

    guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl,
          let url = URL(string: externalVerificationRedirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
    }

    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )
    let callbackUrl = try await authSession.start()
    return try await signIn.handleRedirectCallbackUrl(callbackUrl)
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
    let signIn = try await signInService.create(params: .init(
      identifier: emailAddress,
      strategy: .enterpriseSSO,
      redirectUrl: clerk.options.redirectConfig.redirectUrl
    ))

    guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl,
          let url = URL(string: externalVerificationRedirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
    }

    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )
    let callbackUrl = try await authSession.start()
    return try await signIn.handleRedirectCallbackUrl(callbackUrl)
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
  public func signUpWithOAuth(provider: OAuthProvider, prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    let signUp = try await signUpService.create(params: .init(
      strategy: FactorStrategy(rawValue: provider.strategy),
      redirectUrl: clerk.options.redirectConfig.redirectUrl
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

  /// Signs up with the account portal.
  ///
  /// - Parameter prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the account portal flow fails.
  #if !os(tvOS) && !os(watchOS)
  @discardableResult
  public func signUpWithAccountPortal(prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    let signUp = try await signUpService.create(params: .init(
      strategy: FactorStrategy(rawValue: "account_portal"),
      redirectUrl: clerk.options.redirectConfig.redirectUrl
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
      redirectUrl: clerk.options.redirectConfig.redirectUrl
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

  /// Retrieves the user's session token for the given template or the default clerk token.
  ///
  /// This method uses a cache so a network request will only be made if the token in memory is expired.
  /// The TTL for clerk token is one minute.
  ///
  /// - Parameter options: Options for token retrieval. See `Session.GetTokenOptions` for details.
  /// - Returns: A `TokenResource` containing the session token, or nil if no active session exists.
  /// - Throws: An error if token retrieval fails.
  @discardableResult
  public func getToken(_ options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
    guard let session = clerk.session else {
      return nil
    }
    return try await session.getToken(options)
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

  // MARK: - Deep Link Handling

  /// Handles OAuth/SSO deep link callbacks.
  ///
  /// Call this method from your app's URL handler (e.g., `onOpenURL` in SwiftUI or `SceneDelegate`).
  ///
  /// - Parameter url: The callback URL from the OAuth provider or SSO flow.
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if handling the callback fails.
  @discardableResult
  public func handle(_ url: URL) async throws -> TransferFlowResult? {
    // Check if this is an OAuth callback
    if ExternalAuthUtils.nonceFromCallbackUrl(url: url) != nil {
      // Try to find an active sign-in or sign-up with this nonce
      // For now, we'll need to track active auth attempts or query by nonce
      // This is a simplified implementation - may need enhancement
      return nil
    }
    return nil
  }

  // MARK: - Events

  /// The event emitter for auth events.
  let eventEmitter = EventEmitter<AuthEvent>()

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
}
