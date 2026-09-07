//
//  SignIn.swift
//

// swiftlint:disable file_length

import AuthenticationServices
import ClerkSnapshots
import Foundation

extension SignIn {
  #if !os(tvOS) && !os(watchOS)
  /// Completes enterprise SSO after your app receives the callback URL.
  ///
  /// This pairs with ``Auth/startEnterpriseSSO(emailAddress:redirectUrl:)`` when your app handles browser presentation itself.
  ///
  /// - Parameters:
  ///   - callbackURL: The callback URL your app received after the user completed enterprise SSO.
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  ///   - unsafeMetadata: Custom metadata to attach if this flow creates a sign-up (optional).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if completing enterprise SSO fails.
  @discardableResult
  @MainActor
  public func completeEnterpriseSSO(
    callbackURL: URL,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    try await handleRedirectCallbackUrl(
      callbackURL,
      transferable: transferable,
      unsafeMetadata: unsafeMetadata
    )
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Authenticates with Apple using Sign in with Apple.
  ///
  /// This method handles the entire Sign in with Apple flow for an existing sign-in, including:
  /// - Requesting Apple ID credentials
  /// - Extracting the ID token
  /// - Attempting authentication with the existing sign-in
  /// - Handling the transfer flow if needed
  ///
  /// - Parameters:
  ///   - requestedScopes: The scopes to request from Apple (defaults to `[.email, .fullName]`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  ///   - unsafeMetadata: Custom metadata to attach if this flow creates a sign-up (optional).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithApple(
    requestedScopes: [ASAuthorization.Scope] = [.email, .fullName],
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    let credential = try await SignInWithAppleHelper.getAppleIdCredential(requestedScopes: requestedScopes)

    guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
      throw ClerkClientError(message: "Unable to retrieve the Apple identity token.", localizationBundle: .module)
    }

    let signIn = try await authenticateWithIdToken(idToken, provider: .apple)
    let result = try await signIn.handleTransferFlow(
      transferable: transferable,
      unsafeMetadata: unsafeMetadata
    )
    if case .signIn(let signIn) = result, let error = signIn.firstFactorVerification?.kitError {
      throw error
    }
    return result
  }
  #endif

  // MARK: - Enterprise SSO

  #if !os(tvOS) && !os(watchOS)
  /// Authenticates with Enterprise SSO.
  ///
  /// This method prepares the enterprise SSO first factor and initiates the redirect flow.
  /// After the user completes authentication with their identity provider, the callback URL
  /// is handled automatically.
  ///
  /// - Parameters:
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  ///   - unsafeMetadata: Custom metadata to attach if this flow creates a sign-up (optional).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the enterprise SSO flow fails.
  @discardableResult
  @MainActor
  public func authenticateWithEnterpriseSSO(
    prefersEphemeralWebBrowserSession: Bool = false,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    try await Clerk.authenticateWithRedirect(
      strategy: FactorStrategy.enterpriseSSO.rawValue,
      identifier: identifier,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
      transferable: transferable,
      unsafeMetadata: unsafeMetadata
    )
  }

  /// Authenticates with OAuth using the specified provider.
  ///
  /// This method prepares the OAuth first factor and initiates the redirect flow.
  /// After the user completes authentication with the OAuth provider, the callback URL
  /// is handled automatically.
  ///
  /// - Parameters:
  ///   - provider: The OAuth provider to use (e.g., `.google`, `.github`).
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  ///   - unsafeMetadata: Custom metadata to attach if this flow creates a sign-up (optional).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the OAuth flow fails.
  @discardableResult
  @MainActor
  public func authenticateWithOAuth(
    provider: OAuthProvider,
    prefersEphemeralWebBrowserSession: Bool = false,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    try await Clerk.authenticateWithRedirect(
      strategy: provider.strategy,
      identifier: identifier,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
      transferable: transferable,
      unsafeMetadata: unsafeMetadata
    )
  }
  #endif

  // MARK: - Passkey

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Authenticates with a passkey.
  ///
  /// If this sign-in requires a second factor and advertises passkey support, this method reuses
  /// the in-progress sign-in and completes the passkey as its second factor. Otherwise, it prepares
  /// and attempts the passkey as the first factor.
  ///
  /// - Parameters:
  ///   - autofill: Whether to use autofill-assisted flow for a first factor (default is `false`).
  ///     This value is ignored when passkey is used as a second factor.
  ///   - preferImmediatelyAvailableCredentials: Whether to prefer immediately available credentials (default is `true`).
  /// - Returns: An updated `SignIn` object reflecting the authentication result.
  /// - Throws: An error if passkey authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithPasskey(autofill: Bool = false, preferImmediatelyAvailableCredentials: Bool = true) async throws -> SignIn {
    do {
      return try await authenticateWithPasskeyWithFailureContext(
        autofill: autofill,
        preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
      )
    } catch {
      throw error.underlyingError
    }
  }

  @discardableResult
  @MainActor
  package func authenticateWithPasskeyWithFailureContext(
    autofill: Bool = false,
    preferImmediatelyAvailableCredentials: Bool = true
  ) async throws(PasskeyAuthenticationFailure) -> SignIn {
    do {
      try await Clerk.js(
        .clerk,
        JSRawCall("authenticateNativePasskey", JSONValue(encoding: NativePasskeyArgs(
          expectedId: id,
          autofill: autofill,
          preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
        )))
      )
      return try Clerk.requireEngineSignIn()
    } catch let error as PasskeyAuthenticationFailure {
      throw error
    } catch {
      throw PasskeyAuthenticationFailure(stage: .preparingFirstFactor, underlyingError: error)
    }
  }
  #endif
}

extension SignIn {
  // MARK: - Internal Helpers

  /// Handles the callback url from external authentication. Determines whether to return a sign in or sign up.
  @discardableResult @MainActor
  func handleRedirectCallbackUrl(
    _ url: URL,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    try await Clerk.completeNativeRedirectCallback(
      flow: "signIn", expectedId: id, callbackUrl: url, transferable: transferable, unsafeMetadata: unsafeMetadata
    )
  }

  /// The first factor matching the specified strategy string.
  package func identifyingFirstFactor(for strategy: String) -> Factor? {
    firstFactors.first(where: { factor in
      factor.strategy.rawValue == strategy && factor.safeIdentifier == identifier
    })
  }

  /// The first factor matching the specified strategy string and identifier.
  package func identifyingFirstFactor(for strategy: String, matching identifier: String) -> Factor? {
    firstFactors.first(where: { factor in
      factor.strategy.rawValue == strategy && factor.safeIdentifier == identifier
    })
  }
}

private struct NativePasskeyArgs: Encodable {
  let expectedId: String
  let autofill: Bool
  let preferImmediatelyAvailableCredentials: Bool
}
