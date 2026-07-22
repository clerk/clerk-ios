//
//  Auth+HostedAuth.swift
//  Clerk
//

import Foundation

#if !os(tvOS) && !os(watchOS)

typealias HostedAuthWebAuthentication = @MainActor @Sendable (
  _ url: URL,
  _ callbackUrlScheme: String,
  _ prefersEphemeralWebBrowserSession: Bool
) async throws -> URL

extension Auth {
  @MainActor private static var isHostedAuthInFlight = false

  /// Opens Clerk's hosted authentication flow and activates the created session.
  ///
  /// Completion is observable through the returned ``Session`` and ``AuthEvent/sessionChanged(oldValue:newValue:)``
  /// events; hosted authentication does not emit ``AuthEvent/signInCompleted(signIn:)`` or
  /// ``AuthEvent/signUpCompleted(signUp:)`` events.
  ///
  /// Only custom-scheme callback URLs are supported; `http`, `https`, and universal-link
  /// callback URLs are rejected.
  ///
  /// - Parameters:
  ///   - mode: The Account Portal screen to open. When omitted, Account Portal opens sign-in.
  ///   - redirectUrl: A custom-scheme callback URL. Defaults to Clerk's configured redirect URL,
  ///     which is `{bundleIdentifier}://callback` unless overridden. The web authentication session
  ///     delivers the callback directly, so the scheme does not need to be registered in the
  ///     app's `Info.plist` for this flow.
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral browser session. Defaults to `false`.
  /// - Returns: The session created and activated by hosted authentication.
  /// - Throws: An error if hosted authentication cannot be completed or the callback is invalid.
  @discardableResult
  public func startHostedAuth(
    mode: HostedAuthMode? = nil,
    redirectUrl: String? = nil,
    prefersEphemeralWebBrowserSession: Bool = false
  ) async throws -> Session {
    try await performHostedAuth(
      mode: mode,
      redirectUrl: redirectUrl,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
      webAuthentication: Self.startHostedAuthWebAuthentication
    )
  }

  @discardableResult
  func performHostedAuth(
    mode: HostedAuthMode?,
    redirectUrl: String?,
    prefersEphemeralWebBrowserSession: Bool,
    webAuthentication: HostedAuthWebAuthentication
  ) async throws -> Session {
    guard !Self.isHostedAuthInFlight else {
      throw ClerkClientError(message: "A hosted authentication session is already in progress.")
    }
    Self.isHostedAuthInFlight = true
    defer { Self.isHostedAuthInFlight = false }

    let clerk = Clerk.shared
    let runtime = clerk.runtimeScope
    let clientResponseGeneration = clerk.clientResponseGeneration

    let redirect = try HostedAuthRedirect(redirectUrl ?? clerk.options.redirectConfig.redirectUrl)
    let state = try HostedAuthState.generate()
    let pkce = try PKCE.generatePair()

    let createParams = HostedAuthCreateParams(
      redirectUrl: redirect.rawValue,
      codeChallenge: pkce.challenge,
      state: state,
      mode: mode
    )
    let hostedAuth: HostedAuthResource
    do {
      hostedAuth = try await hostedAuthService.create(params: createParams)
    } catch let error as ClerkAPIError where error.code == "signed_out" {
      // Reconcile an abandoned handoff before retrying once with the same request inputs.
      try await clerk.refreshClient(skipClientId: true)
      hostedAuth = try await hostedAuthService.create(params: createParams)
    }
    let hostedAuthUrl = try hostedAuth.authenticationUrl()

    let callbackUrl = try await webAuthentication(
      hostedAuthUrl,
      redirect.callbackUrlScheme,
      prefersEphemeralWebBrowserSession
    )
    let callback = try HostedAuthCallback(url: callbackUrl, redirect: redirect, state: state)

    // A reconfiguration while the browser was open invalidates this flow; fail
    // before the redeem request consumes the single-use rotating token nonce.
    try runtime.validateStableRuntime()

    let response = try await hostedAuthService.redeem(params: HostedAuthRedeemParams(
      rotatingTokenNonce: callback.rotatingTokenNonce,
      codeVerifier: pkce.verifier
    ))
    try runtime.validateStableRuntime()

    guard
      let returnedClient = response.client,
      returnedClient.sessions.contains(where: { $0.id == callback.createdSessionId })
    else {
      throw ClerkClientError(message: "Hosted auth completion did not include the created session.")
    }

    clerk.applyResponseClient(
      returnedClient,
      responseSequence: response.requestSequence,
      serverDate: response.serverDate,
      clientResponseGeneration: clientResponseGeneration
    )
    guard clerk.client?.sessions.contains(where: { $0.id == callback.createdSessionId }) == true else {
      throw ClerkClientError(message: "Hosted auth completion could not update the current client.")
    }

    try await activateSession(sessionId: callback.createdSessionId)
    guard
      clerk.client?.lastActiveSessionId == callback.createdSessionId,
      let activeSession = clerk.client?.sessions.first(where: { $0.id == callback.createdSessionId })
    else {
      throw ClerkClientError(message: "Hosted auth completion could not activate the created session.")
    }
    return activeSession
  }

  private static func startHostedAuthWebAuthentication(
    url: URL,
    callbackUrlScheme: String,
    prefersEphemeralWebBrowserSession: Bool
  ) async throws -> URL {
    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
      callbackURLScheme: callbackUrlScheme
    )
    return try await authSession.start()
  }
}

#endif
