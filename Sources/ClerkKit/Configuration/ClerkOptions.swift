//
//  ClerkOptions.swift
//  Clerk
//
//  Created by Mike Pitre on 6/30/25.
//

import FactoryKit
import Foundation

extension Clerk {

  /// A configuration object that can be passed to `Clerk.configure()` to customize various aspects of the Clerk SDK behavior.
  public struct ClerkOptions: Sendable {

    /// Enable additional debugging signals and logging. Defaults to false.
    public let debugMode: Bool

    /// Enable development telemetry collection. Defaults to true.
    public let telemetryEnabled: Bool

    /// Configuration for keychain storage behavior.
    public let keychainConfig: KeychainConfig

    /// Your Clerk app's proxy URL. Required for applications that run behind a reverse proxy. Must be a full URL (for example, https://proxy.example.com/__clerk).
    public let proxyUrl: URL?

    /// Configuration for OAuth redirect URLs and callback handling.
    public let redirectConfig: RedirectConfig

    /// Initializes a ``ClerkOptions`` instance.
    /// - Parameters:
    ///   - debugMode: Enable additional debugging signals and logging. Defaults to false.
    ///   - telemetryEnabled: Enable development telemetry collection. Defaults to true.
    ///   - keychainConfig: Configuration for keychain storage behavior.
    ///   - proxyUrl: Your Clerk app's proxy URL. Required for applications that run behind a reverse proxy—must be a full URL (e.g. https://proxy.example.com/__clerk). Defaults to nil.
    ///   - redirectConfig: Configuration for OAuth redirect URLs and callback handling.
    public init(
      debugMode: Bool = false,
      telemetryEnabled: Bool = true,
      keychainConfig: KeychainConfig = .init(),
      proxyUrl: String? = nil,
      redirectConfig: RedirectConfig = .init()
    ) {
      self.debugMode = debugMode
      self.telemetryEnabled = telemetryEnabled
      self.keychainConfig = keychainConfig
      self.proxyUrl = proxyUrl.flatMap { URL(string: $0) }
      self.redirectConfig = redirectConfig
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

extension Container {
  
  var clerkOptions: Factory<Clerk.ClerkOptions> {
    self { .init() }
      .cached
  }
  
}

