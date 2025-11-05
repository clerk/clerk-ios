//
//  SystemKeychainTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Tests for SystemKeychain keychain operations.
@Suite(.serialized)
struct SystemKeychainTests {

  @Test
  func testSetAndGetData() throws {
    let keychain = SystemKeychain(
      service: "com.clerk.test",
      accessGroup: nil
    )

    let testData = "test-value".data(using: .utf8)!
    try keychain.set(testData, forKey: "test-key")

    let retrievedData = try keychain.data(forKey: "test-key")
    #expect(retrievedData == testData)
  }

  @Test
  func testUpdateExistingKey() throws {
    let keychain = SystemKeychain(
      service: "com.clerk.test",
      accessGroup: nil
    )

    let initialData = "initial-value".data(using: .utf8)!
    try keychain.set(initialData, forKey: "test-key")

    let updatedData = "updated-value".data(using: .utf8)!
    try keychain.set(updatedData, forKey: "test-key")

    let retrievedData = try keychain.data(forKey: "test-key")
    #expect(retrievedData == updatedData)
  }

  @Test
  func testDeleteItem() throws {
    let keychain = SystemKeychain(
      service: "com.clerk.test",
      accessGroup: nil
    )

    let testData = "test-value".data(using: .utf8)!
    try keychain.set(testData, forKey: "test-key")

    try keychain.deleteItem(forKey: "test-key")

    let retrievedData = try keychain.data(forKey: "test-key")
    #expect(retrievedData == nil)
  }

  @Test
  func testHasItem() throws {
    let keychain = SystemKeychain(
      service: "com.clerk.test",
      accessGroup: nil
    )

    #expect(try keychain.hasItem(forKey: "non-existent-key") == false)

    let testData = "test-value".data(using: .utf8)!
    try keychain.set(testData, forKey: "existing-key")

    #expect(try keychain.hasItem(forKey: "existing-key") == true)
  }

  @Test
  func testGetNonExistentKeyReturnsNil() throws {
    let keychain = SystemKeychain(
      service: "com.clerk.test",
      accessGroup: nil
    )

    let data = try keychain.data(forKey: "non-existent-key")
    #expect(data == nil)
  }

  @Test
  func testDeleteNonExistentKeyDoesNotThrow() throws {
    let keychain = SystemKeychain(
      service: "com.clerk.test",
      accessGroup: nil
    )

    // Should not throw when deleting non-existent key
    try keychain.deleteItem(forKey: "non-existent-key")
  }

  @Test
  func testIsolationBetweenServices() throws {
    let keychain1 = SystemKeychain(
      service: "com.clerk.test1",
      accessGroup: nil
    )

    let keychain2 = SystemKeychain(
      service: "com.clerk.test2",
      accessGroup: nil
    )

    let testData = "test-value".data(using: .utf8)!
    try keychain1.set(testData, forKey: "shared-key")

    // Key should not be visible in different service
    let data = try keychain2.data(forKey: "shared-key")
    #expect(data == nil)
  }
}

