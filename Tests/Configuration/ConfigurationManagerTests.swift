//
//  ConfigurationManagerTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct ConfigurationManagerTests {
  // Helper to create a valid test publishable key
  // Format: pk_test_{base64_encoded_url_with_$}
  func createTestPublishableKey(for url: String) -> String {
    // Add $ at the end and encode to base64URL
    let urlWithDollar = url + "$"
    let data = urlWithDollar.data(using: .utf8)!
    let base64 = data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    return "pk_test_\(base64)"
  }

  func createLivePublishableKey(for url: String) -> String {
    let urlWithDollar = url + "$"
    let data = urlWithDollar.data(using: .utf8)!
    let base64 = data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    return "pk_live_\(base64)"
  }

  @Test
  func configureWithValidTestKey() throws {
    let manager = ConfigurationManager()
    let testKey = createTestPublishableKey(for: "clerk.example.com")
    let options = Clerk.ClerkOptions()

    try manager.configure(publishableKey: testKey, options: options)

    #expect(manager.publishableKey == testKey)
    #expect(manager.instanceType == .development)
    #expect(manager.frontendApiUrl.contains("clerk.example.com"))
    #expect(manager.options.logLevel == .error)
  }

  @Test
  func configureWithValidLiveKey() throws {
    let manager = ConfigurationManager()
    let liveKey = createLivePublishableKey(for: "clerk.production.com")
    let options = Clerk.ClerkOptions()

    try manager.configure(publishableKey: liveKey, options: options)

    #expect(manager.publishableKey == liveKey)
    #expect(manager.instanceType == .production)
    #expect(manager.frontendApiUrl.contains("clerk.production.com"))
  }

  @Test
  func configureWithEmptyKey() {
    let manager = ConfigurationManager()
    let options = Clerk.ClerkOptions()

    do {
      try manager.configure(publishableKey: "", options: options)
      Issue.record("Expected missingPublishableKey error")
    } catch let error as ClerkInitializationError {
      if case .missingPublishableKey = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func configureWithWhitespaceOnlyKey() {
    let manager = ConfigurationManager()
    let options = Clerk.ClerkOptions()

    do {
      try manager.configure(publishableKey: "   ", options: options)
      Issue.record("Expected missingPublishableKey error")
    } catch let error as ClerkInitializationError {
      if case .missingPublishableKey = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func configureWithInvalidFormatKey() {
    let manager = ConfigurationManager()
    let options = Clerk.ClerkOptions()

    do {
      try manager.configure(publishableKey: "invalid_key", options: options)
      Issue.record("Expected invalidPublishableKeyFormat error")
    } catch let error as ClerkInitializationError {
      if case .invalidPublishableKeyFormat = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func configureWithKeyStartingWithWrongPrefix() {
    let manager = ConfigurationManager()
    let options = Clerk.ClerkOptions()

    do {
      try manager.configure(publishableKey: "pk_invalid_something", options: options)
      Issue.record("Expected invalidPublishableKeyFormat error")
    } catch let error as ClerkInitializationError {
      if case .invalidPublishableKeyFormat = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func configureWithInvalidBase64InKey() {
    let manager = ConfigurationManager()
    let options = Clerk.ClerkOptions()

    do {
      try manager.configure(publishableKey: "pk_test_invalid!!!", options: options)
      Issue.record("Expected invalidPublishableKeyFormat error")
    } catch let error as ClerkInitializationError {
      if case .invalidPublishableKeyFormat = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func instanceTypeDevelopment() throws {
    let manager = ConfigurationManager()
    let testKey = createTestPublishableKey(for: "clerk.example.com")
    let options = Clerk.ClerkOptions()

    try manager.configure(publishableKey: testKey, options: options)

    #expect(manager.instanceType == .development)
  }

  @Test
  func instanceTypeProduction() throws {
    let manager = ConfigurationManager()
    let liveKey = createLivePublishableKey(for: "clerk.production.com")
    let options = Clerk.ClerkOptions()

    try manager.configure(publishableKey: liveKey, options: options)

    #expect(manager.instanceType == .production)
  }

  @Test
  func frontendApiUrlExtraction() throws {
    let manager = ConfigurationManager()
    let testKey = createTestPublishableKey(for: "clerk.example.com")
    let options = Clerk.ClerkOptions()

    try manager.configure(publishableKey: testKey, options: options)

    #expect(manager.frontendApiUrl == "https://clerk.example.com")
  }

  @Test
  func testUpdateProxyUrl() throws {
    let manager = ConfigurationManager()
    let testKey = createTestPublishableKey(for: "clerk.example.com")
    let options = Clerk.ClerkOptions()

    try manager.configure(publishableKey: testKey, options: options)

    let proxyURL = URL(string: "https://proxy.example.com/__clerk")
    manager.updateProxyUrl(proxyURL)

    #expect(manager.proxyUrl == proxyURL)
    #expect(manager.proxyConfiguration != nil)
    #expect(manager.proxyConfiguration?.baseURL.host == "proxy.example.com")
  }

  @Test
  func updateProxyUrlToNil() throws {
    let manager = ConfigurationManager()
    let testKey = createTestPublishableKey(for: "clerk.example.com")
    let options = Clerk.ClerkOptions(proxyUrl: "https://proxy.example.com/__clerk")

    try manager.configure(publishableKey: testKey, options: options)

    #expect(manager.proxyUrl != nil)

    manager.updateProxyUrl(nil)

    #expect(manager.proxyUrl == nil)
    #expect(manager.proxyConfiguration == nil)
  }

  @Test
  func testUpdateFrontendApiUrl() throws {
    let manager = ConfigurationManager()
    let testKey = createTestPublishableKey(for: "clerk.example.com")
    let options = Clerk.ClerkOptions()

    try manager.configure(publishableKey: testKey, options: options)

    let newUrl = "https://new.example.com"
    manager.updateFrontendApiUrl(newUrl)

    #expect(manager.frontendApiUrl == newUrl)
  }

  @Test
  func configureWithCustomOptions() throws {
    let manager = ConfigurationManager()
    let testKey = createTestPublishableKey(for: "clerk.example.com")
    let customOptions = Clerk.ClerkOptions(
      logLevel: .debug,
      telemetryEnabled: false,
      proxyUrl: "https://proxy.example.com/__clerk"
    )

    try manager.configure(publishableKey: testKey, options: customOptions)

    #expect(manager.options.logLevel == .debug)
    #expect(manager.options.telemetryEnabled == false)
    #expect(manager.proxyUrl?.absoluteString == "https://proxy.example.com/__clerk")
  }

  @Test
  func propertyAccessors() throws {
    let manager = ConfigurationManager()
    let testKey = createTestPublishableKey(for: "clerk.example.com")
    let options = Clerk.ClerkOptions()

    try manager.configure(publishableKey: testKey, options: options)

    // Test all property accessors
    #expect(!manager.publishableKey.isEmpty)
    #expect(!manager.frontendApiUrl.isEmpty)
    #expect(manager.options.logLevel == .error)
    #expect(manager.instanceType == .development)
  }

  @Test
  func proxyConfigurationFromOptions() throws {
    let manager = ConfigurationManager()
    let testKey = createTestPublishableKey(for: "clerk.example.com")
    let proxyURL = URL(string: "https://proxy.example.com/__clerk")
    let options = Clerk.ClerkOptions(proxyUrl: proxyURL?.absoluteString)

    try manager.configure(publishableKey: testKey, options: options)

    #expect(manager.proxyConfiguration != nil)
    #expect(manager.proxyConfiguration?.baseURL.host == "proxy.example.com")
    #expect(manager.proxyConfiguration?.pathSegments == ["__clerk"])
  }

  @Test
  func configureWithKeyContainingWhitespace() {
    let manager = ConfigurationManager()
    // Key with leading/trailing whitespace will pass validation (trims internally)
    // but will fail extraction because extraction uses the original key
    let testKey = createTestPublishableKey(for: "clerk.example.com")
    let options = Clerk.ClerkOptions()

    let keyWithWhitespace = "  \(testKey)  "

    do {
      try manager.configure(publishableKey: keyWithWhitespace, options: options)
      Issue.record("Expected invalidPublishableKeyFormat error during URL extraction")
    } catch let error as ClerkInitializationError {
      if case .invalidPublishableKeyFormat = error {
        // Expected error - extraction fails because key has whitespace
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }
}
