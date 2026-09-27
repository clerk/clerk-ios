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
  #if os(macOS)
  @Test
  func migrationEnumerationReadsRealKeychainItemsOnlyFromItsService() throws {
    let service = "clerk.migration.enumeration.\(UUID().uuidString)"
    let keychain = SystemKeychain(service: service)
    let unrelated = SystemKeychain(service: "\(service).unrelated")
    defer {
      try? keychain.deleteItem(forKey: "owner.a")
      try? keychain.deleteItem(forKey: "owner.b")
      try? unrelated.deleteItem(forKey: "owner.other")
    }
    try keychain.set(Data("a".utf8), forKey: "owner.a")
    try keychain.set(Data("b".utf8), forKey: "owner.b")
    try unrelated.set(Data("other".utf8), forKey: "owner.other")

    #expect(try keychain.allItems() == ["owner.a": Data("a".utf8), "owner.b": Data("b".utf8)])
  }
  #endif

  @Test
  func migrationEnumerationIsScopedToTheConfiguredServiceAndGroup() throws {
    let spy = SecItemClientSpy()
    let first = Data("first-slot".utf8)
    let second = Data("second-slot".utf8)
    spy.copyMatchingResults = [.items([
      [kSecAttrAccount as String: "owner.a"],
      [kSecAttrAccount as String: "owner.b"],
    ]), .success(first), .success(second)]
    let keychain = SystemKeychain(service: "legacy-slots", accessGroup: "group",
                                  useDataProtectionKeychain: true, secItemClient: spy.client)

    #expect(try keychain.allItems() == ["owner.a": first, "owner.b": second])
    let query = try #require(spy.copyMatchingQueries.first)
    #expect(query[kSecAttrService as String] as? String == "legacy-slots")
    #expect(query[kSecAttrAccessGroup as String] as? String == "group")
    #expect(query[kSecAttrAccount as String] == nil)
    #expect(query[kSecMatchLimit as String] as? String == kSecMatchLimitAll as String)
    #expect(query[kSecReturnAttributes as String] as? Bool == true)
    #expect(query[kSecReturnData as String] == nil)
    #expect(hasDataProtectionKeychainFlag(query))
    #expect(spy.copyMatchingQueries.dropFirst().compactMap { $0[kSecAttrAccount as String] as? String } == ["owner.a", "owner.b"])
    #expect(spy.copyMatchingQueries.allSatisfy { $0[kSecAttrService as String] as? String == "legacy-slots" })
    #expect(spy.copyMatchingQueries.allSatisfy { $0[kSecAttrAccessGroup as String] as? String == "group" })
  }

  @Test
  func unavailableMigrationEnumerationIsNotAnEmptyGroup() throws {
    let spy = SecItemClientSpy()
    spy.copyMatchingResults = [.status(errSecInteractionNotAllowed), .status(errSecItemNotFound)]
    let keychain = SystemKeychain(service: "legacy-slots", secItemClient: spy.client)
    #expect(throws: (any Error).self) { try keychain.allItems() }
    #expect(try keychain.allItems().isEmpty)
  }

  @Test
  func conditionalUpdateMatchesTheRevisionAndChangesItWithThePayload() throws {
    let spy = SecItemClientSpy()
    let keychain = SystemKeychain(service: "service", accessGroup: "group", secItemClient: spy.client)
    let expected = UUID()
    let next = UUID()
    let payload = Data("replacement".utf8)
    #expect(try keychain.compareAndSwap(payload, forKey: "identity", expectedRevision: expected, newRevision: next))
    let query = try #require(spy.updateQueries.first)
    let attributes = try #require(spy.updateAttributes.first)
    #expect(query[kSecAttrGeneric as String] as? Data == Data(expected.uuidString.utf8))
    #expect(query[kSecAttrAccessGroup as String] as? String == "group")
    #expect(query[kSecAttrAccount as String] as? String == "identity")
    #expect(attributes[kSecAttrGeneric as String] as? Data == Data(next.uuidString.utf8))
    #expect(attributes[kSecValueData as String] as? Data == payload)
    #expect(spy.addQueries.isEmpty)
  }

  @Test
  func aConditionalUpdateConflictNeverFallsBackToAdd() throws {
    let spy = SecItemClientSpy()
    spy.updateResults = [errSecItemNotFound]
    let keychain = SystemKeychain(service: "service", secItemClient: spy.client)
    #expect(try !keychain.compareAndSwap(Data(), forKey: "identity", expectedRevision: UUID(), newRevision: UUID()))
    #expect(spy.updateQueries.count == 1)
    #expect(spy.addQueries.isEmpty)
  }

  @Test
  func aConditionalCreationConflictNeverFallsBackToUpdate() throws {
    let spy = SecItemClientSpy()
    spy.addResults = [errSecDuplicateItem]
    let keychain = SystemKeychain(service: "service", secItemClient: spy.client)
    #expect(try !keychain.compareAndSwap(Data(), forKey: "identity", expectedRevision: nil, newRevision: UUID()))
    #expect(spy.addQueries.count == 1)
    #expect(spy.updateQueries.isEmpty)
  }

  @Test
  func conditionalWriteAccessFailureIsNotAConflict() {
    let spy = SecItemClientSpy()
    spy.updateResults = [errSecInteractionNotAllowed]
    let keychain = SystemKeychain(service: "service", secItemClient: spy.client)
    #expect(throws: (any Error).self) {
      try keychain.compareAndSwap(Data(), forKey: "identity", expectedRevision: UUID(), newRevision: UUID())
    }
  }

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

  @Test
  func missingEntitlementErrorIncludesAccessGroupGuidance() {
    let error = KeychainError.unexpectedStatus(errSecMissingEntitlement)

    #expect(error.errorDescription?.contains("OSStatus \(errSecMissingEntitlement)") == true)
    #expect(error.failureReason?.contains("Keychain Sharing") == true)
    #expect(error.failureReason?.contains("accessGroup") == true)
  }

  @Test
  func unexpectedStatusErrorIncludesSystemMessageWhenAvailable() throws {
    let error = KeychainError.unexpectedStatus(errSecItemNotFound)
    let systemMessage = try #require(SecCopyErrorMessageString(errSecItemNotFound, nil) as String?)

    #expect(error.errorDescription?.contains("OSStatus \(errSecItemNotFound)") == true)
    #expect(error.errorDescription?.contains(systemMessage) == true)
  }
}

private final class SecItemClientSpy: @unchecked Sendable {
  enum CopyMatchingResult {
    case success(Data)
    case items([[String: Any]])
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
        case .items(let items):
          result?.pointee = items as CFArray
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
