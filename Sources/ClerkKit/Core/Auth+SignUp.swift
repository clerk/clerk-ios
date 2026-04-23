//
//  Auth+SignUp.swift
//  Clerk
//

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
import Foundation

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
