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
@Suite(.serialized)
struct ClerkKeychainKeyTests {
  @Test
  func allCasesContainsExpectedKeys() {
    let allCases = ClerkKeychainKey.allCases
    #expect(allCases.count == 11)

    // Verify all expected keys are present
    #expect(allCases.contains(.cachedClient))
    #expect(allCases.contains(.cachedClientServerDate))
    #expect(allCases.contains(.cachedEnvironment))
    #expect(allCases.contains(.clerkAuthState))
    #expect(allCases.contains(.clerkAuthVersion))
    #expect(allCases.contains(.clerkDeviceToken))
    #expect(allCases.contains(.clerkDeviceTokenState))
    #expect(allCases.contains(.clerkDeviceTokenVersion))
    #expect(allCases.contains(.clerkDeviceTokenSynced))
    #expect(allCases.contains(.attestKeyId))
    #expect(allCases.contains(.pendingMagicLinkFlow))
  }

  @Test
  func rawValuesMatchExpectedStrings() {
    #expect(ClerkKeychainKey.cachedClient.rawValue == "cachedClient")
    #expect(ClerkKeychainKey.cachedClientServerDate.rawValue == "cachedClientServerDate")
    #expect(ClerkKeychainKey.cachedEnvironment.rawValue == "cachedEnvironment")
    #expect(ClerkKeychainKey.clerkAuthState.rawValue == "clerkAuthState")
    #expect(ClerkKeychainKey.clerkAuthVersion.rawValue == "clerkAuthVersion")
    #expect(ClerkKeychainKey.clerkDeviceToken.rawValue == "clerkDeviceToken")
    #expect(ClerkKeychainKey.clerkDeviceTokenState.rawValue == "clerkDeviceTokenState")
    #expect(ClerkKeychainKey.clerkDeviceTokenVersion.rawValue == "clerkDeviceTokenVersion")
    #expect(ClerkKeychainKey.clerkDeviceTokenSynced.rawValue == "clerkDeviceTokenSynced")
    #expect(ClerkKeychainKey.attestKeyId.rawValue == "AttestKeyId")
    #expect(ClerkKeychainKey.pendingMagicLinkFlow.rawValue == "pendingMagicLinkFlow")
  }
}
