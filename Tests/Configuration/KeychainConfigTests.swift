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
  func defaultInitialization() {
    let config = KeychainConfig()

    #expect(config.service == Bundle.main.bundleIdentifier ?? "")
    #expect(config.accessGroup == nil)
  }

  @Test
  func initializationWithService() {
    let config = KeychainConfig(service: "com.example.service")

    #expect(config.service == "com.example.service")
    #expect(config.accessGroup == nil)
  }

  @Test
  func initializationWithAccessGroup() {
    let config = KeychainConfig(accessGroup: "group.com.example")

    #expect(config.service == Bundle.main.bundleIdentifier ?? "")
    #expect(config.accessGroup == "group.com.example")
  }

  @Test
  func initializationWithAllParameters() {
    let config = KeychainConfig(
      service: "com.example.service",
      accessGroup: "group.com.example"
    )

    #expect(config.service == "com.example.service")
    #expect(config.accessGroup == "group.com.example")
  }

  @Test
  func propertyAccess() {
    let config = KeychainConfig(service: "test", accessGroup: "group")

    _ = config.service
    _ = config.accessGroup

    #expect(config.service == "test")
    #expect(config.accessGroup == "group")
  }
}
