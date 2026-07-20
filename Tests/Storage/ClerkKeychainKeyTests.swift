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
    #expect(allCases.count == 17)

    // Verify all expected keys are present
    #expect(allCases.contains(.cachedClient))
    #expect(allCases.contains(.cachedClientServerDate))
    #expect(allCases.contains(.cachedEnvironment))
    #expect(allCases.contains(.sharedSessionSyncAuthState))
    #expect(allCases.contains(.sharedSessionSyncAuthVersion))
    #expect(allCases.contains(.sharedSessionSyncEnvironmentVersion))
    #expect(allCases.contains(.watchSyncAuthState))
    #expect(allCases.contains(.watchSyncAuthVersion))
    #expect(allCases.contains(.clerkDeviceToken))
    #expect(allCases.contains(.sharedSessionSyncDeviceTokenState))
    #expect(allCases.contains(.sharedSessionSyncDeviceTokenVersion))
    #expect(allCases.contains(.watchSyncDeviceTokenState))
    #expect(allCases.contains(.watchSyncDeviceTokenVersion))
    #expect(allCases.contains(.watchSyncDeviceTokenSynced))
    #expect(allCases.contains(.attestKeyId))
    #expect(allCases.contains(.pendingMagicLinkFlow))
    #expect(allCases.contains(.trustedDeviceCredentials))
  }

  @Test
  func rawValuesMatchExpectedStrings() {
    #expect(ClerkKeychainKey.cachedClient.rawValue == "cachedClient")
    #expect(ClerkKeychainKey.cachedClientServerDate.rawValue == "cachedClientServerDate")
    #expect(ClerkKeychainKey.cachedEnvironment.rawValue == "cachedEnvironment")
    #expect(ClerkKeychainKey.sharedSessionSyncAuthState.rawValue == "sharedSessionSyncAuthState")
    #expect(ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue == "sharedSessionSyncAuthVersion")
    #expect(ClerkKeychainKey.sharedSessionSyncEnvironmentVersion.rawValue == "sharedSessionSyncEnvironmentVersion")
    #expect(ClerkKeychainKey.watchSyncAuthState.rawValue == "watchSyncAuthState")
    #expect(ClerkKeychainKey.watchSyncAuthVersion.rawValue == "watchSyncAuthVersion")
    #expect(ClerkKeychainKey.clerkDeviceToken.rawValue == "clerkDeviceToken")
    #expect(ClerkKeychainKey.sharedSessionSyncDeviceTokenState.rawValue == "sharedSessionSyncDeviceTokenState")
    #expect(ClerkKeychainKey.sharedSessionSyncDeviceTokenVersion.rawValue == "sharedSessionSyncDeviceTokenVersion")
    #expect(ClerkKeychainKey.watchSyncDeviceTokenState.rawValue == "watchSyncDeviceTokenState")
    #expect(ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue == "watchSyncDeviceTokenVersion")
    #expect(ClerkKeychainKey.watchSyncDeviceTokenSynced.rawValue == "clerkDeviceTokenSynced")
    #expect(ClerkKeychainKey.attestKeyId.rawValue == "AttestKeyId")
    #expect(ClerkKeychainKey.pendingMagicLinkFlow.rawValue == "pendingMagicLinkFlow")
    #expect(ClerkKeychainKey.trustedDeviceCredentials.rawValue == "trustedDeviceCredentials")
  }
}
