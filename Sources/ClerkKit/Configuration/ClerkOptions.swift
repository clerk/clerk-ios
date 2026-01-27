//
//  ClerkOptions.swift
//  Clerk
//
//  Created by Mike Pitre on 6/30/25.
//

import Foundation

extension Clerk {
  /// A configuration object that can be passed to `Clerk.configure()` to customize various aspects of the Clerk SDK behavior.
  public struct ClerkOptions: Sendable {
    /// The minimum log level for SDK logging. Defaults to `.error` (minimal logging).
    public let logLevel: LogLevel

    /// Enable development telemetry collection. Defaults to true.
    public let telemetryEnabled: Bool

    /// Configuration for keychain storage behavior.
    public let keychainConfig: KeychainConfig

    /// Your Clerk app's proxy URL. Required for applications that run behind a reverse proxy. Must be a full URL (for example, https://proxy.example.com/__clerk).
    public let proxyUrl: URL?

    /// Configuration for OAuth redirect URLs and callback handling.
    public let redirectConfig: RedirectConfig

    /// Enable Watch Connectivity to sync authentication state (deviceToken, Client, Environment) to companion watchOS app. Defaults to false.
    public let watchConnectivityEnabled: Bool

    /// A closure that receives callbacks when Clerk logs errors.
    ///
    /// Set this property to forward Clerk errors to your own logging system.
    /// The closure is invoked asynchronously and will not block the main thread.
    /// Only error-level logs will trigger the closure.
    public let loggerHandler: (@Sendable (LogEntry) -> Void)?

    /// Middleware to run as the final step before sending a request.
    ///
    /// Use this to inject custom headers or diagnostics after Clerk has prepared the request.
    ///
    /// ```swift
    /// struct CustomHeaderMiddleware: ClerkRequestMiddleware {
    ///   func prepare(_ request: inout URLRequest) async throws {
    ///     request.setValue("custom-value", forHTTPHeaderField: "x-custom-header")
    ///   }
    /// }
    ///
    /// let options = Clerk.ClerkOptions(
    ///   requestMiddleware: [CustomHeaderMiddleware()]
    /// )
    /// ```
    public let requestMiddleware: [any ClerkRequestMiddleware]

    /// Middleware to run immediately after receiving a response.
    ///
    /// Custom response middleware runs before Clerk's built-in response middleware.
    ///
    /// ```swift
    /// struct ResponseDiagnosticsMiddleware: ClerkResponseMiddleware {
    ///   func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) throws {
    ///     // Inspect response or emit diagnostics here.
    ///   }
    /// }
    ///
    /// let options = Clerk.ClerkOptions(
    ///   responseMiddleware: [ResponseDiagnosticsMiddleware()]
    /// )
    /// ```
    public let responseMiddleware: [any ClerkResponseMiddleware]

    /// Initializes a ``ClerkOptions`` instance.
    /// - Parameters:
    ///   - logLevel: The minimum log level for SDK logging. Defaults to `.error` (minimal logging). Use `.debug` or `.verbose` for more detailed logs.
    ///   - telemetryEnabled: Enable development telemetry collection. Defaults to true.
    ///   - keychainConfig: Configuration for keychain storage behavior.
    ///   - proxyUrl: Your Clerk app's proxy URL. Required for applications that run behind a reverse proxy—must be a full URL (e.g. https://proxy.example.com/__clerk). Defaults to nil.
    ///   - redirectConfig: Configuration for OAuth redirect URLs and callback handling.
    ///   - watchConnectivityEnabled: Enable Watch Connectivity to sync authentication state (deviceToken, Client, Environment) to companion watchOS app. Defaults to false.
    ///   - loggerHandler: A closure that receives callbacks when Clerk logs errors. Set this to forward Clerk errors to your own logging system. Defaults to nil.
    ///   - requestMiddleware: Middleware to run as the final step before sending a request. Defaults to an empty array.
    ///   - responseMiddleware: Middleware to run immediately after receiving a response. Custom response middleware runs before Clerk's built-in response middleware. Defaults to an empty array.
    public init(
      logLevel: LogLevel = .error,
      telemetryEnabled: Bool = true,
      keychainConfig: KeychainConfig = .init(),
      proxyUrl: String? = nil,
      redirectConfig: RedirectConfig = .init(),
      watchConnectivityEnabled: Bool = false,
      loggerHandler: (@Sendable (LogEntry) -> Void)? = nil,
      requestMiddleware: [any ClerkRequestMiddleware] = [],
      responseMiddleware: [any ClerkResponseMiddleware] = []
    ) {
      self.logLevel = logLevel
      self.telemetryEnabled = telemetryEnabled
      self.keychainConfig = keychainConfig
      self.proxyUrl = proxyUrl.flatMap { URL(string: $0) }
      self.redirectConfig = redirectConfig
      self.watchConnectivityEnabled = watchConnectivityEnabled
      self.loggerHandler = loggerHandler
      self.requestMiddleware = requestMiddleware
      self.responseMiddleware = responseMiddleware
    }
  }
}

/// A configuration object that can be passed to `Clerk.configure()` to customize keychain behavior.
public struct KeychainConfig: Sendable {
  /// Name of the service under which to save items. Defaults to the bundle identifier.
  public let service: String

  /// Access group for sharing Keychain items.
  public let accessGroup: String?

  /// Initializes a ``KeychainConfig`` instance.
  /// - Parameters:
  ///   - service: Name of the service under which to save items. Defaults to the bundle identifier.
  ///   - accessGroup: Access group for sharing Keychain items.
  public init(
    service: String = Bundle.main.bundleIdentifier ?? "",
    accessGroup: String? = nil
  ) {
    self.service = service
    self.accessGroup = accessGroup
  }
}

/// A configuration object that can be passed to `Clerk.configure()` to customize redirect behavior for OAuth flows and deep linking.
public struct RedirectConfig: Sendable {
  /// The URL that OAuth providers should redirect to after authentication. Defaults to "{bundleIdentifier}://callback".
  public let redirectUrl: String

  /// The URL scheme used for handling callbacks from OAuth providers. Defaults to the bundle identifier.
  public let callbackUrlScheme: String

  /// Initializes a ``RedirectConfig`` instance.
  /// - Parameters:
  ///   - redirectUrl: The URL that OAuth providers should redirect to after authentication. Defaults to "{bundleIdentifier}://callback".
  ///   - callbackUrlScheme: The URL scheme used for handling callbacks from OAuth providers. Defaults to the bundle identifier.
  public init(
    redirectUrl: String = "\(Bundle.main.bundleIdentifier ?? "")://callback",
    callbackUrlScheme: String = Bundle.main.bundleIdentifier ?? ""
  ) {
    self.redirectUrl = redirectUrl
    self.callbackUrlScheme = callbackUrlScheme
  }
}
