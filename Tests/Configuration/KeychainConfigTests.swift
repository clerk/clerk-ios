//
//  KeychainConfigTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct KeychainConfigTests {
  @Test
  func defaultInitialization() {
    let config = Clerk.Options.KeychainConfig()

    #expect(config.service == Bundle.main.bundleIdentifier ?? "")
    #expect(config.accessGroup == nil)
    #expect(config.appLocalAccessGroup == nil)
  }

  @Test
  func initializationWithService() {
    let config = Clerk.Options.KeychainConfig(service: "com.example.service")

    #expect(config.service == "com.example.service")
    #expect(config.accessGroup == nil)
    #expect(config.appLocalAccessGroup == nil)
  }

  @Test
  func initializationWithAccessGroup() {
    let config = Clerk.Options.KeychainConfig(accessGroup: "group.com.example")

    #expect(config.service == Bundle.main.bundleIdentifier ?? "")
    #expect(config.accessGroup == "group.com.example")
    #expect(config.appLocalAccessGroup == nil)
  }

  @Test
  func initializationWithAllParameters() {
    let config = Clerk.Options.KeychainConfig(
      service: "com.example.service",
      accessGroup: "TEAMID.group.com.example",
      appLocalAccessGroup: "TEAMID.com.example.app"
    )

    #expect(config.service == "com.example.service")
    #expect(config.accessGroup == "TEAMID.group.com.example")
    #expect(config.appLocalAccessGroup == "TEAMID.com.example.app")
  }

  @Test
  func propertyAccess() {
    let config = Clerk.Options.KeychainConfig(service: "test", accessGroup: "group")

    _ = config.service
    _ = config.accessGroup
    _ = config.appLocalAccessGroup

    #expect(config.service == "test")
    #expect(config.accessGroup == "group")
    #expect(config.appLocalAccessGroup == nil)
  }

  @Test
  func normalizesAppLocalAccessGroup() {
    let config = Clerk.Options.KeychainConfig(
      appLocalAccessGroup: "  TEAMID.com.example.app\n"
    )

    #expect(config.normalizedAppLocalAccessGroup == "TEAMID.com.example.app")
  }
}
