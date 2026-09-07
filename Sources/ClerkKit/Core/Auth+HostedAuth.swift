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
    let clerk = Clerk.shared
    let ownerId = AuthFlowRequestScope.ownerId
    let flow = try await Clerk.js(
      .clerk,
      JSRawCall("beginNativeHostedAuth", JSONValue(encoding: HostedAuthOptions(
        redirectUrl: redirectUrl ?? clerk.options.redirectConfig.redirectUrl, mode: mode
      ))), as: HostedAuthBrowserRequest.self
    )
    do {
      try Task.checkCancellation()
      let callback = try await webAuthentication(flow.url, flow.callbackUrlScheme, prefersEphemeralWebBrowserSession)
      try Task.checkCancellation()
      let completion = try await Clerk.js(
        .clerk,
        JSRawCall("prepareNativeHostedAuthCompletion", .string(flow.id), .string(callback.absoluteString)),
        as: HostedAuthActivation.self
      )
      let activation = clerk.beginAuthSessionActivation(sessionId: completion.sessionId, ownerId: ownerId)
      defer {
        if let activation { clerk.authSessionActivationDidFinish(activation: activation) }
      }
      return try await Clerk.js(.clerk, JSRawCall("completeNativeHostedAuth", .string(flow.id)), as: Session.self)
    } catch {
      try? await Clerk.js(.clerk, JSRawCall("cancelNativeHostedAuth", .string(flow.id)))
      throw error
    }
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

private struct HostedAuthOptions: Encodable {
  var redirectUrl: String
  var mode: HostedAuthMode?
}

private struct HostedAuthBrowserRequest: Decodable {
  var id: String
  var url: URL
  var callbackUrlScheme: String
}

private struct HostedAuthActivation: Decodable {
  var sessionId: String
}

#endif
