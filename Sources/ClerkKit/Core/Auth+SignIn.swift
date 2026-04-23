//
//  Auth+SignIn.swift
//  Clerk
//

import AuthenticationServices
import Foundation

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
