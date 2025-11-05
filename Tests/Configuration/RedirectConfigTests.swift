//
//  RedirectConfigTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct RedirectConfigTests {
  @Test
  func defaultInitialization() {
    let config = RedirectConfig()
    let bundleId = Bundle.main.bundleIdentifier ?? ""

    #expect(config.redirectUrl == "\(bundleId)://callback")
    #expect(config.callbackUrlScheme == bundleId)
  }

  @Test
  func initializationWithRedirectUrl() {
    let config = RedirectConfig(redirectUrl: "test://redirect")

    #expect(config.redirectUrl == "test://redirect")
    #expect(config.callbackUrlScheme == Bundle.main.bundleIdentifier ?? "")
  }

  @Test
  func initializationWithCallbackUrlScheme() {
    let config = RedirectConfig(callbackUrlScheme: "test")

    #expect(config.redirectUrl == "\(Bundle.main.bundleIdentifier ?? "")://callback")
    #expect(config.callbackUrlScheme == "test")
  }

  @Test
  func initializationWithAllParameters() {
    let config = RedirectConfig(
      redirectUrl: "test://redirect",
      callbackUrlScheme: "test"
    )

    #expect(config.redirectUrl == "test://redirect")
    #expect(config.callbackUrlScheme == "test")
  }

  @Test
  func propertyAccess() {
    let config = RedirectConfig(redirectUrl: "test://redirect", callbackUrlScheme: "test")

    _ = config.redirectUrl
    _ = config.callbackUrlScheme

    #expect(config.redirectUrl == "test://redirect")
    #expect(config.callbackUrlScheme == "test")
  }
}
