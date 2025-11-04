//
//  KeychainConfigTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct KeychainConfigTests {

  @Test
  func testDefaultInitialization() {
    let config = KeychainConfig()

    #expect(config.service == Bundle.main.bundleIdentifier ?? "")
    #expect(config.accessGroup == nil)
  }

  @Test
  func testInitializationWithService() {
    let config = KeychainConfig(service: "com.example.service")

    #expect(config.service == "com.example.service")
    #expect(config.accessGroup == nil)
  }

  @Test
  func testInitializationWithAccessGroup() {
    let config = KeychainConfig(accessGroup: "group.com.example")

    #expect(config.service == Bundle.main.bundleIdentifier ?? "")
    #expect(config.accessGroup == "group.com.example")
  }

  @Test
  func testInitializationWithAllParameters() {
    let config = KeychainConfig(
      service: "com.example.service",
      accessGroup: "group.com.example"
    )

    #expect(config.service == "com.example.service")
    #expect(config.accessGroup == "group.com.example")
  }

  @Test
  func testPropertyAccess() {
    let config = KeychainConfig(service: "test", accessGroup: "group")

    let _ = config.service
    let _ = config.accessGroup

    #expect(config.service == "test")
    #expect(config.accessGroup == "group")
  }
}

