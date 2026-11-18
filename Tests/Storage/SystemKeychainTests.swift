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

@Suite(.serialized)
struct SystemKeychainTests {
  @Test
  func duplicateItemOnSetUpdatesTheStoredValue() throws {
    let secItemClient = SecItemClientSpy()
    secItemClient.addResults = [errSecDuplicateItem]
    let keychain = SystemKeychain(service: "service", secItemClient: secItemClient.client)
    let newData = Data("updated-value".utf8)

    try keychain.set(newData, forKey: "key")

    let query = try #require(secItemClient.updateQueries.first)
    let attributes = try #require(secItemClient.updateAttributes.first)
    #expect(query[kSecAttrAccount as String] as? String == "key")
    #expect(attributes[kSecValueData as String] as? Data == newData)
  }

  @Test
  func deleteItemTargetsTheServiceAndKey() throws {
    let secItemClient = SecItemClientSpy()
    let keychain = SystemKeychain(service: "service", secItemClient: secItemClient.client)

    try keychain.deleteItem(forKey: "key")

    let query = try #require(secItemClient.deleteQueries.first)
    #expect(query[kSecAttrService as String] as? String == "service")
    #expect(query[kSecAttrAccount as String] as? String == "key")
  }

  @Test
  func hasItemIsTrueOnlyWhenTheKeychainFindsTheItem() throws {
    let secItemClient = SecItemClientSpy()
    let keychain = SystemKeychain(service: "service", secItemClient: secItemClient.client)

    secItemClient.copyMatchingResults = [.status(errSecSuccess)]
    #expect(try keychain.hasItem(forKey: "key") == true)

    #expect(try keychain.hasItem(forKey: "key") == false)
  }

  @Test
  func deletingAnAbsentItemIsNotAnError() throws {
    let secItemClient = SecItemClientSpy()
    secItemClient.deleteResults = [errSecItemNotFound]
    let keychain = SystemKeychain(service: "service", secItemClient: secItemClient.client)

    try keychain.deleteItem(forKey: "key")
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
