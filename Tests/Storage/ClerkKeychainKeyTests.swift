//
//  ClerkKeychainKeyTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation
import Testing

/// Tests for ClerkKeychainKey enum.
@Suite(.tags(.unit))
struct ClerkKeychainKeyTests {
  @Test
  func allCasesContainsExpectedKeys() {
    let allCases = ClerkKeychainKey.allCases
    #expect(allCases.count == 6)

    // Verify all expected keys are present
    #expect(allCases.contains(.cachedClient))
    #expect(allCases.contains(.cachedClientServerDate))
    #expect(allCases.contains(.cachedEnvironment))
    #expect(allCases.contains(.clerkDeviceToken))
    #expect(allCases.contains(.clerkDeviceTokenSynced))
    #expect(allCases.contains(.attestKeyId))
  }

  @Test
  func rawValuesMatchExpectedStrings() {
    #expect(ClerkKeychainKey.cachedClient.rawValue == "cachedClient")
    #expect(ClerkKeychainKey.cachedClientServerDate.rawValue == "cachedClientServerDate")
    #expect(ClerkKeychainKey.cachedEnvironment.rawValue == "cachedEnvironment")
    #expect(ClerkKeychainKey.clerkDeviceToken.rawValue == "clerkDeviceToken")
    #expect(ClerkKeychainKey.clerkDeviceTokenSynced.rawValue == "clerkDeviceTokenSynced")
    #expect(ClerkKeychainKey.attestKeyId.rawValue == "AttestKeyId")
  }
}
