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
