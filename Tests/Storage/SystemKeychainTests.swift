//
//  SystemKeychainTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation
import Security
import Testing

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

  @Test
  func dataProtectionKeychainWritesUseDataProtectionFlag() throws {
    let secItemClient = SecItemClientSpy()
    let keychain = SystemKeychain(
      service: "service",
      accessGroup: "group.example",
      useDataProtectionKeychain: true,
      secItemClient: secItemClient.client
    )

    try keychain.set(Data("value".utf8), forKey: "key")

    let query = try #require(secItemClient.addQueries.first)
    #expect(query[kSecAttrAccessGroup as String] as? String == "group.example")
    #expect(hasDataProtectionKeychainFlag(query))
  }

  @Test
  func accessGroupWithoutDataProtectionFlagUsesLegacyKeychain() throws {
    let secItemClient = SecItemClientSpy()
    let keychain = SystemKeychain(
      service: "service",
      accessGroup: "group.example",
      secItemClient: secItemClient.client
    )

    try keychain.set(Data("value".utf8), forKey: "key")

    let query = try #require(secItemClient.addQueries.first)
    #expect(query[kSecAttrAccessGroup as String] as? String == "group.example")
    #expect(!hasDataProtectionKeychainFlag(query))
  }

  @Test
  func noAccessGroupUsesLegacyKeychain() throws {
    let secItemClient = SecItemClientSpy()
    let keychain = SystemKeychain(
      service: "service",
      secItemClient: secItemClient.client
    )

    try keychain.set(Data("value".utf8), forKey: "key")

    let query = try #require(secItemClient.addQueries.first)
    #expect(query[kSecAttrAccessGroup as String] == nil)
    #expect(!hasDataProtectionKeychainFlag(query))
  }

  @Test
  func dataReadsFromConfiguredBackendOnly() throws {
    let secItemClient = SecItemClientSpy()
    secItemClient.copyMatchingResults = [
      .success(Data("value".utf8)),
    ]
    let keychain = SystemKeychain(
      service: "service",
      accessGroup: "group.example",
      useDataProtectionKeychain: true,
      secItemClient: secItemClient.client
    )

    let data = try keychain.data(forKey: "key")

    #expect(data == Data("value".utf8))
    #expect(secItemClient.copyMatchingQueries.count == 1)
    #expect(hasDataProtectionKeychainFlag(secItemClient.copyMatchingQueries[0]))
  }
}

private final class SecItemClientSpy: @unchecked Sendable {
  enum CopyMatchingResult {
    case success(Data)
    case status(OSStatus)
  }

  var addResults: [OSStatus] = []
  var updateResults: [OSStatus] = []
  var copyMatchingResults: [CopyMatchingResult] = []
  var deleteResults: [OSStatus] = []

  var addQueries: [[String: Any]] = []
  var updateQueries: [[String: Any]] = []
  var updateAttributes: [[String: Any]] = []
  var copyMatchingQueries: [[String: Any]] = []
  var deleteQueries: [[String: Any]] = []

  var client: SystemKeychain.SecItemClient {
    .init(
      add: { query, _ in
        self.addQueries.append(Self.dictionary(from: query))
        return self.addResults.isEmpty ? errSecSuccess : self.addResults.removeFirst()
      },
      update: { query, attributes in
        self.updateQueries.append(Self.dictionary(from: query))
        self.updateAttributes.append(Self.dictionary(from: attributes))
        return self.updateResults.isEmpty ? errSecSuccess : self.updateResults.removeFirst()
      },
      copyMatching: { query, result in
        self.copyMatchingQueries.append(Self.dictionary(from: query))

        guard !self.copyMatchingResults.isEmpty else {
          return errSecItemNotFound
        }

        switch self.copyMatchingResults.removeFirst() {
        case .success(let data):
          result?.pointee = data as CFData
          return errSecSuccess
        case .status(let status):
          return status
        }
      },
      delete: { query in
        self.deleteQueries.append(Self.dictionary(from: query))
        return self.deleteResults.isEmpty ? errSecSuccess : self.deleteResults.removeFirst()
      }
    )
  }

  private static func dictionary(from query: CFDictionary) -> [String: Any] {
    query as NSDictionary as? [String: Any] ?? [:]
  }
}

private func hasDataProtectionKeychainFlag(_ query: [String: Any]) -> Bool {
  query[kSecUseDataProtectionKeychain as String] as? Bool == true
}
