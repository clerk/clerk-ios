//
//  ConfigurationManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import RegexBuilder

@MainActor
final class ConfigurationManager {
  struct ConfigurationState {
    var publishableKey: String = ""
    var frontendApiUrl: String = ""
    var proxyUrl: URL?
    var proxyConfiguration: ProxyConfiguration?
    var options: Clerk.Options = .init()
    var isConfigured: Bool = false
  }

  private var state = ConfigurationState()

  /// Configures the Clerk instance with the provided publishable key and options.
  ///
  /// - Parameters:
  ///   - publishableKey: The publishable key from Clerk Dashboard.
  ///   - options: Configuration options for the Clerk instance.
  ///
  /// - Throws: `ClerkInitializationError` if the publishable key is invalid or configuration fails.
  func configure(publishableKey: String, options: Clerk.Options) throws {
    let normalizedPublishableKey = publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)

    try validatePublishableKey(normalizedPublishableKey)
    let proxyConfiguration = try makeProxyConfiguration(for: options)

    state.publishableKey = normalizedPublishableKey
    state.options = options

    state.frontendApiUrl = try extractFrontendApiUrl(from: normalizedPublishableKey)

    state.proxyUrl = options.proxyUrl
    state.proxyConfiguration = proxyConfiguration

    state.isConfigured = true
  }

  func updateProxyUrl(_ proxyUrl: URL?) {
    state.proxyUrl = proxyUrl
    state.proxyConfiguration = ProxyConfiguration(url: proxyUrl)
  }

  func updateFrontendApiUrl(_ frontendApiUrl: String) {
    state.frontendApiUrl = frontendApiUrl
  }

  var frontendApiUrl: String {
    state.frontendApiUrl
  }

  var proxyConfiguration: ProxyConfiguration? {
    state.proxyConfiguration
  }

  var proxyUrl: URL? {
    state.proxyUrl
  }

  var publishableKey: String {
    state.publishableKey
  }

  var options: Clerk.Options {
    state.options
  }

  var instanceType: InstanceEnvironmentType {
    if state.publishableKey.starts(with: "pk_live_") {
      return .production
    }
    return .development
  }

  /// Validates the publishable key format and throws an error if invalid.
  ///
  /// - Parameter key: The publishable key to validate.
  /// - Throws: `ClerkInitializationError` if the key is empty or has an invalid format.
  private func validatePublishableKey(_ key: String) throws {
    guard !key.isEmpty else {
      throw ClerkInitializationError.missingPublishableKey
    }

    guard key.starts(with: "pk_test_") || key.starts(with: "pk_live_") else {
      throw ClerkInitializationError.invalidPublishableKeyFormat(key: key)
    }
  }

  /// Builds the proxy configuration for the proxy URL the app passed.
  ///
  /// Requests would skip a proxy URL that `ProxyConfiguration` can't build from and go straight to the
  /// Frontend API, so an explicit one fails configuration instead. An omitted or blank value means no proxy.
  ///
  /// - Throws: `ClerkInitializationError.invalidProxyUrl` if the proxy URL isn't an http or https URL with a host.
  private func makeProxyConfiguration(for options: Clerk.Options) throws -> ProxyConfiguration? {
    guard let input = options.proxyUrlInput,
          !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return nil }

    guard let configuration = ProxyConfiguration(url: options.proxyUrl) else {
      throw ClerkInitializationError.invalidProxyUrl
    }
    return configuration
  }

  /// Extracts the frontend API URL from a publishable key.
  ///
  /// The publishable key contains encoded information that can be used to derive the API URL.
  /// Assumes the publishable key has already been validated.
  ///
  /// - Parameter publishableKey: The publishable key to extract the URL from (must be validated).
  /// - Returns: The extracted frontend API URL.
  /// - Throws: `ClerkInitializationError.invalidPublishableKeyFormat` if the key format is invalid.
  private func extractFrontendApiUrl(from publishableKey: String) throws -> String {
    let liveRegex = Regex {
      "pk_live_"
      Capture {
        OneOrMore(.any)
      }
    }

    let testRegex = Regex {
      "pk_test_"
      Capture {
        OneOrMore(.any)
      }
    }

    guard let match = publishableKey.firstMatch(of: liveRegex)?.output.1 ?? publishableKey.firstMatch(of: testRegex)?.output.1,
          let apiUrl = String(match).base64String()
    else {
      throw ClerkInitializationError.invalidPublishableKeyFormat(key: publishableKey)
    }

    return "https://\(apiUrl.dropLast())"
  }
}
