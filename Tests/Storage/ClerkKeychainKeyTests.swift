//
//  ClerkKeychainKeyTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct ClerkKeychainKeyTests {
  @Test
  func allCasesContainsExpectedKeys() {
    let allCases = ClerkKeychainKey.allCases
    #expect(allCases.count == 13)

    #expect(allCases.contains(.cachedClient))
    #expect(allCases.contains(.cachedClientServerDate))
    #expect(allCases.contains(.cachedEnvironment))
    #expect(allCases.contains(.watchSyncLastChange))
    #expect(allCases.contains(.sharedSessionSyncAuthState))
    #expect(allCases.contains(.sharedSessionSyncAuthVersion))
    #expect(allCases.contains(.sharedSessionSyncEnvironmentVersion))
    #expect(allCases.contains(.clerkDeviceToken))
    #expect(allCases.contains(.sharedSessionSyncDeviceTokenState))
    #expect(allCases.contains(.sharedSessionSyncDeviceTokenVersion))
    #expect(allCases.contains(.attestKeyId))
    #expect(allCases.contains(.pendingMagicLinkFlow))
    #expect(allCases.contains(.biometricCredentials))
  }

  @Test
  func rawValuesMatchExpectedStrings() {
    #expect(ClerkKeychainKey.cachedClient.rawValue == "cachedClient")
    #expect(ClerkKeychainKey.cachedClientServerDate.rawValue == "cachedClientServerDate")
    #expect(ClerkKeychainKey.cachedEnvironment.rawValue == "cachedEnvironment")
    #expect(ClerkKeychainKey.sharedSessionSyncAuthState.rawValue == "sharedSessionSyncAuthState")
    #expect(ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue == "sharedSessionSyncAuthVersion")
    #expect(ClerkKeychainKey.sharedSessionSyncEnvironmentVersion.rawValue == "sharedSessionSyncEnvironmentVersion")
    #expect(ClerkKeychainKey.clerkDeviceToken.rawValue == "clerkDeviceToken")
    #expect(ClerkKeychainKey.sharedSessionSyncDeviceTokenState.rawValue == "sharedSessionSyncDeviceTokenState")
    #expect(ClerkKeychainKey.sharedSessionSyncDeviceTokenVersion.rawValue == "sharedSessionSyncDeviceTokenVersion")
    #expect(ClerkKeychainKey.attestKeyId.rawValue == "AttestKeyId")
    #expect(ClerkKeychainKey.pendingMagicLinkFlow.rawValue == "pendingMagicLinkFlow")
    #expect(ClerkKeychainKey.biometricCredentials.rawValue == "trustedDeviceCredentials")
  }
}
