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
  func testDefaultInitialization() {
    let config = RedirectConfig()
    let bundleId = Bundle.main.bundleIdentifier ?? ""

    #expect(config.redirectUrl == "\(bundleId)://callback")
    #expect(config.callbackUrlScheme == bundleId)
  }

  @Test
  func testInitializationWithRedirectUrl() {
    let config = RedirectConfig(redirectUrl: "test://redirect")

    #expect(config.redirectUrl == "test://redirect")
    #expect(config.callbackUrlScheme == Bundle.main.bundleIdentifier ?? "")
  }

  @Test
  func testInitializationWithCallbackUrlScheme() {
    let config = RedirectConfig(callbackUrlScheme: "test")

    #expect(config.redirectUrl == "\(Bundle.main.bundleIdentifier ?? "")://callback")
    #expect(config.callbackUrlScheme == "test")
  }

  @Test
  func testInitializationWithAllParameters() {
    let config = RedirectConfig(
      redirectUrl: "test://redirect",
      callbackUrlScheme: "test"
    )

    #expect(config.redirectUrl == "test://redirect")
    #expect(config.callbackUrlScheme == "test")
  }

  @Test
  func testPropertyAccess() {
    let config = RedirectConfig(redirectUrl: "test://redirect", callbackUrlScheme: "test")

    let _ = config.redirectUrl
    let _ = config.callbackUrlScheme

    #expect(config.redirectUrl == "test://redirect")
    #expect(config.callbackUrlScheme == "test")
  }
}

