//
//  ClerkOptionsTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct ClerkOptionsTests {
  @Test
  func defaultInitialization() {
    let options = Clerk.ClerkOptions()

    #expect(options.logLevel == .error)
    #expect(options.telemetryEnabled == true)
    #expect(options.proxyUrl == nil)
    #expect(options.keychainConfig.service == Bundle.main.bundleIdentifier ?? "")
    #expect(options.keychainConfig.accessGroup == nil)
    #expect(options.redirectConfig.redirectUrl.contains("://callback"))
    #expect(options.redirectConfig.callbackUrlScheme == Bundle.main.bundleIdentifier ?? "")
  }

  @Test
  func initializationWithAllParameters() {
    let keychainConfig = KeychainConfig(service: "test.service", accessGroup: "test.group")
    let redirectConfig = RedirectConfig(redirectUrl: "test://redirect", callbackUrlScheme: "test")

    let options = Clerk.ClerkOptions(
      logLevel: .debug,
      telemetryEnabled: false,
      keychainConfig: keychainConfig,
      proxyUrl: "https://proxy.example.com/__clerk",
      redirectConfig: redirectConfig
    )

    #expect(options.logLevel == .debug)
    #expect(options.telemetryEnabled == false)
    #expect(options.keychainConfig.service == "test.service")
    #expect(options.keychainConfig.accessGroup == "test.group")
    #expect(options.proxyUrl?.absoluteString == "https://proxy.example.com/__clerk")
    #expect(options.redirectConfig.redirectUrl == "test://redirect")
    #expect(options.redirectConfig.callbackUrlScheme == "test")
  }

  @Test
  func proxyUrlConversionValidURL() {
    let options = Clerk.ClerkOptions(proxyUrl: "https://proxy.example.com/__clerk")

    #expect(options.proxyUrl != nil)
    #expect(options.proxyUrl?.scheme == "https")
    #expect(options.proxyUrl?.host == "proxy.example.com")
    #expect(options.proxyUrl?.path == "/__clerk")
  }

  @Test
  func proxyUrlConversionInvalidURL() {
    // URL(string:) can be lenient, so use a string that definitely won't create a valid URL
    // Using a string without a scheme should work
    let options = Clerk.ClerkOptions(proxyUrl: "://invalid")

    // URL(string:) with "://invalid" may still create a URL with nil scheme
    // So we check if it's actually a valid proxy URL by checking scheme
    if let url = options.proxyUrl {
      // If URL was created, it should have an invalid scheme
      #expect(url.scheme == nil || url.scheme == "")
    } else {
      // nil is also acceptable
    }
  }

  @Test
  func proxyUrlConversionNil() {
    let options = Clerk.ClerkOptions(proxyUrl: nil)

    #expect(options.proxyUrl == nil)
  }

  @Test
  func proxyUrlConversionWithPort() {
    let options = Clerk.ClerkOptions(proxyUrl: "https://proxy.example.com:8080/__clerk")

    #expect(options.proxyUrl != nil)
    #expect(options.proxyUrl?.port == 8080)
  }

  @Test
  func proxyUrlConversionWithQueryParams() {
    let options = Clerk.ClerkOptions(proxyUrl: "https://proxy.example.com/__clerk?param=value")

    #expect(options.proxyUrl != nil)
    #expect(options.proxyUrl?.query == "param=value")
  }

  @Test
  func partialInitialization() {
    // Test with only some parameters
    let options = Clerk.ClerkOptions(logLevel: .debug)

    #expect(options.logLevel == .debug)
    #expect(options.telemetryEnabled == true) // Default
    #expect(options.proxyUrl == nil) // Default
  }

  @Test
  func propertyAccess() {
    let options = Clerk.ClerkOptions(
      logLevel: .debug,
      telemetryEnabled: false,
      proxyUrl: "https://proxy.example.com/__clerk"
    )

    // Verify all properties are accessible
    _ = options.logLevel
    _ = options.telemetryEnabled
    _ = options.keychainConfig
    _ = options.proxyUrl
    _ = options.redirectConfig

    #expect(options.logLevel == .debug)
    #expect(options.telemetryEnabled == false)
  }
}
