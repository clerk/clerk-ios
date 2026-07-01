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
    #expect(allCases.contains(.watchSyncAuthState))
    #expect(allCases.contains(.watchSyncAuthVersion))
    #expect(allCases.contains(.clerkDeviceToken))
    #expect(allCases.contains(.watchSyncDeviceTokenState))
    #expect(allCases.contains(.watchSyncDeviceTokenVersion))
    #expect(allCases.contains(.watchSyncDeviceTokenSynced))
    #expect(allCases.contains(.attestKeyId))
    #expect(allCases.contains(.pendingMagicLinkFlow))
  }

  @Test
  func rawValuesMatchExpectedStrings() {
    #expect(ClerkKeychainKey.cachedClient.rawValue == "cachedClient")
    #expect(ClerkKeychainKey.cachedClientServerDate.rawValue == "cachedClientServerDate")
    #expect(ClerkKeychainKey.cachedEnvironment.rawValue == "cachedEnvironment")
    #expect(ClerkKeychainKey.watchSyncAuthState.rawValue == "watchSyncAuthState")
    #expect(ClerkKeychainKey.watchSyncAuthVersion.rawValue == "watchSyncAuthVersion")
    #expect(ClerkKeychainKey.clerkDeviceToken.rawValue == "clerkDeviceToken")
    #expect(ClerkKeychainKey.watchSyncDeviceTokenState.rawValue == "watchSyncDeviceTokenState")
    #expect(ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue == "watchSyncDeviceTokenVersion")
    #expect(ClerkKeychainKey.watchSyncDeviceTokenSynced.rawValue == "clerkDeviceTokenSynced")
    #expect(ClerkKeychainKey.attestKeyId.rawValue == "AttestKeyId")
    #expect(ClerkKeychainKey.pendingMagicLinkFlow.rawValue == "pendingMagicLinkFlow")
  }
}
