//
//  SystemKeychainTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Tests for KeychainStorage protocol operations.
/// Uses InMemoryKeychain for fast, isolated unit tests that don't require keychain entitlements.
@Suite(.serialized)
struct SystemKeychainTests {
  @Test
  func setAndGetData() throws {
    let keychain = InMemoryKeychain()

    let testData = "test-value".data(using: .utf8)!
    try keychain.set(testData, forKey: "test-key")

    let retrievedData = try keychain.data(forKey: "test-key")
    #expect(retrievedData == testData)
  }

  @Test
  func updateExistingKey() throws {
    let keychain = InMemoryKeychain()

    let initialData = "initial-value".data(using: .utf8)!
    try keychain.set(initialData, forKey: "test-key")

    let updatedData = "updated-value".data(using: .utf8)!
    try keychain.set(updatedData, forKey: "test-key")

    let retrievedData = try keychain.data(forKey: "test-key")
    #expect(retrievedData == updatedData)
  }

  @Test
  func testDeleteItem() throws {
    let keychain = InMemoryKeychain()

    let testData = "test-value".data(using: .utf8)!
    try keychain.set(testData, forKey: "test-key")

    try keychain.deleteItem(forKey: "test-key")

    let retrievedData = try keychain.data(forKey: "test-key")
    #expect(retrievedData == nil)
  }

  @Test
  func testHasItem() throws {
    let keychain = InMemoryKeychain()

    #expect(try keychain.hasItem(forKey: "non-existent-key") == false)

    let testData = "test-value".data(using: .utf8)!
    try keychain.set(testData, forKey: "existing-key")

    #expect(try keychain.hasItem(forKey: "existing-key") == true)
  }

  @Test
  func getNonExistentKeyReturnsNil() throws {
    let keychain = InMemoryKeychain()

    let data = try keychain.data(forKey: "non-existent-key")
    #expect(data == nil)
  }

  @Test
  func deleteNonExistentKeyDoesNotThrow() throws {
    let keychain = InMemoryKeychain()

    // Should not throw when deleting non-existent key
    try keychain.deleteItem(forKey: "non-existent-key")
  }

  @Test
  func isolationBetweenInstances() throws {
    let keychain1 = InMemoryKeychain()
    let keychain2 = InMemoryKeychain()

    let testData = "test-value".data(using: .utf8)!
    try keychain1.set(testData, forKey: "shared-key")

    // Key should not be visible in different instance
    let data = try keychain2.data(forKey: "shared-key")
    #expect(data == nil)
  }
}
