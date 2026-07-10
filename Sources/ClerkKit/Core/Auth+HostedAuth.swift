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

@MainActor
private enum HostedAuthInFlightGate {
  private static var isAcquired = false

  static func acquire() throws {
    guard !isAcquired else {
      throw ClerkClientError(message: "A hosted authentication session is already in progress.")
    }
    isAcquired = true
  }

  static func release() {
    isAcquired = false
  }
}

extension Auth {
  /// Opens Clerk's hosted authentication flow and activates the created session.
  ///
  /// - Parameters:
  ///   - mode: The Account Portal screen to open. When omitted, Account Portal opens sign-in.
  ///   - redirectUrl: A custom-scheme callback URL. Defaults to Clerk's configured redirect URL,
  ///     which is `{bundleIdentifier}://callback` unless overridden. Register the URL scheme in the app.
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
    try HostedAuthInFlightGate.acquire()
    defer { HostedAuthInFlightGate.release() }

    let redirect = try HostedAuthRedirect(redirectUrl ?? Clerk.shared.options.redirectConfig.redirectUrl)
    let state = try HostedAuthState.generate()
    let pkce = try HostedAuthPKCE.generatePair()

    let hostedAuth = try await hostedAuthService.create(params: HostedAuthCreateParams(
      redirectUrl: redirect.rawValue,
      codeChallenge: pkce.challenge,
      state: state,
      mode: mode
    ))
    let hostedAuthUrl = try hostedAuth.authenticationUrl()

    let callbackUrl = try await webAuthentication(
      hostedAuthUrl,
      redirect.callbackUrlScheme,
      prefersEphemeralWebBrowserSession
    )
    let callback = try HostedAuthCallback(url: callbackUrl, redirect: redirect, state: state)

    let clerk = Clerk.shared
    let runtime = clerk.runtimeScope
    let clientResponseGeneration = clerk.clientResponseGeneration
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
