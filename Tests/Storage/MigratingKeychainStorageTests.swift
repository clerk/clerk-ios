//
//  MigratingKeychainStorageTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct MigratingKeychainStorageTests {
  @Test
  func dataMigratesFallbackItemWhenPrimaryItemIsMissing() throws {
    let primary = KeychainStorageSpy()
    let fallback = KeychainStorageSpy()
    let fallbackData = Data("fallback-value".utf8)
    primary.dataResults = [.success(nil)]
    fallback.dataResults = [.success(fallbackData)]

    let keychain = MigratingKeychainStorage(
      primary: primary,
      fallback: fallback
    )

    let data = try keychain.data(forKey: "key")

    #expect(data == fallbackData)
    #expect(primary.dataKeys == ["key"])
    #expect(fallback.dataKeys == ["key"])
    #expect(primary.setCalls == [.init(key: "key", data: fallbackData)])
    #expect(fallback.setCalls.isEmpty)
    #expect(primary.deleteKeys.isEmpty)
    #expect(fallback.deleteKeys.isEmpty)
  }

  @Test
  func dataDoesNotReadFallbackWhenPrimaryItemExists() throws {
    let primary = KeychainStorageSpy()
    let fallback = KeychainStorageSpy()
    let primaryData = Data("primary-value".utf8)
    primary.dataResults = [.success(primaryData)]

    let keychain = MigratingKeychainStorage(
      primary: primary,
      fallback: fallback
    )

    let data = try keychain.data(forKey: "key")

    #expect(data == primaryData)
    #expect(primary.dataKeys == ["key"])
    #expect(fallback.dataKeys.isEmpty)
    #expect(primary.setCalls.isEmpty)
  }

  @Test
  func dataReturnsNilWhenPrimaryAndFallbackMiss() throws {
    let primary = KeychainStorageSpy()
    let fallback = KeychainStorageSpy()
    primary.dataResults = [.success(nil)]
    fallback.dataResults = [.success(nil)]

    let keychain = MigratingKeychainStorage(
      primary: primary,
      fallback: fallback
    )

    let data = try keychain.data(forKey: "key")

    #expect(data == nil)
    #expect(primary.dataKeys == ["key"])
    #expect(fallback.dataKeys == ["key"])
    #expect(primary.setCalls.isEmpty)
  }

  @Test
  func dataReturnsFallbackItemWhenMigrationWriteFails() throws {
    let primary = KeychainStorageSpy()
    let fallback = KeychainStorageSpy()
    let fallbackData = Data("fallback-value".utf8)
    primary.dataResults = [.success(nil)]
    primary.setError = TestKeychainError.writeFailed
    fallback.dataResults = [.success(fallbackData)]

    let keychain = MigratingKeychainStorage(
      primary: primary,
      fallback: fallback
    )

    let data = try keychain.data(forKey: "key")

    #expect(data == fallbackData)
    #expect(primary.setCalls == [.init(key: "key", data: fallbackData)])
    #expect(primary.deleteKeys.isEmpty)
    #expect(fallback.deleteKeys.isEmpty)
  }

  @Test
  func dataDoesNotReadFallbackWhenPrimaryThrows() throws {
    let primary = KeychainStorageSpy()
    let fallback = KeychainStorageSpy()
    primary.dataResults = [.failure(TestKeychainError.readFailed)]

    let keychain = MigratingKeychainStorage(
      primary: primary,
      fallback: fallback
    )

    do {
      _ = try keychain.data(forKey: "key")
      Issue.record("Expected data(forKey:) to throw")
    } catch {
      #expect(error as? TestKeychainError == .readFailed)
      #expect(fallback.dataKeys.isEmpty)
    }
  }

  @Test
  func setWritesOnlyToPrimary() throws {
    let primary = KeychainStorageSpy()
    let fallback = KeychainStorageSpy()
    let keychain = MigratingKeychainStorage(
      primary: primary,
      fallback: fallback
    )

    try keychain.set(Data("value".utf8), forKey: "key")

    #expect(primary.setCalls == [.init(key: "key", data: Data("value".utf8))])
    #expect(fallback.setCalls.isEmpty)
  }

  @Test
  func deleteAttemptsPrimaryAndFallback() throws {
    let primary = KeychainStorageSpy()
    let fallback = KeychainStorageSpy()
    let keychain = MigratingKeychainStorage(
      primary: primary,
      fallback: fallback
    )

    try keychain.deleteItem(forKey: "key")

    #expect(primary.deleteKeys == ["key"])
    #expect(fallback.deleteKeys == ["key"])
  }

  @Test
  func deleteAttemptsFallbackWhenPrimaryDeleteFails() throws {
    let primary = KeychainStorageSpy()
    let fallback = KeychainStorageSpy()
    primary.deleteError = TestKeychainError.deleteFailed
    let keychain = MigratingKeychainStorage(
      primary: primary,
      fallback: fallback
    )

    do {
      try keychain.deleteItem(forKey: "key")
      Issue.record("Expected deleteItem(forKey:) to throw")
    } catch {
      #expect(error as? TestKeychainError == .deleteFailed)
      #expect(primary.deleteKeys == ["key"])
      #expect(fallback.deleteKeys == ["key"])
    }
  }

  @Test
  func hasItemFallsBackWhenPrimaryItemIsMissing() throws {
    let primary = KeychainStorageSpy()
    let fallback = KeychainStorageSpy()
    primary.hasItemResults = [.success(false)]
    fallback.hasItemResults = [.success(true)]
    let keychain = MigratingKeychainStorage(
      primary: primary,
      fallback: fallback
    )

    #expect(try keychain.hasItem(forKey: "key"))
    #expect(primary.hasItemKeys == ["key"])
    #expect(fallback.hasItemKeys == ["key"])
  }

  @Test
  func hasItemDoesNotReadFallbackWhenPrimaryItemExists() throws {
    let primary = KeychainStorageSpy()
    let fallback = KeychainStorageSpy()
    primary.hasItemResults = [.success(true)]
    let keychain = MigratingKeychainStorage(
      primary: primary,
      fallback: fallback
    )

    #expect(try keychain.hasItem(forKey: "key"))
    #expect(primary.hasItemKeys == ["key"])
    #expect(fallback.hasItemKeys.isEmpty)
  }
}

private final class KeychainStorageSpy: KeychainStorage, @unchecked Sendable {
  struct SetCall: Equatable {
    let key: String
    let data: Data
  }

  var dataResults: [Result<Data?, Error>] = []
  var hasItemResults: [Result<Bool, Error>] = []
  var setError: Error?
  var deleteError: Error?

  var setCalls: [SetCall] = []
  var dataKeys: [String] = []
  var deleteKeys: [String] = []
  var hasItemKeys: [String] = []

  func set(_ data: Data, forKey key: String) throws {
    setCalls.append(.init(key: key, data: data))

    if let setError {
      throw setError
    }
  }

  func data(forKey key: String) throws -> Data? {
    dataKeys.append(key)

    guard !dataResults.isEmpty else {
      return nil
    }

    return try dataResults.removeFirst().get()
  }

  func deleteItem(forKey key: String) throws {
    deleteKeys.append(key)

    if let deleteError {
      throw deleteError
    }
  }

  func hasItem(forKey key: String) throws -> Bool {
    hasItemKeys.append(key)

    guard !hasItemResults.isEmpty else {
      return false
    }

    return try hasItemResults.removeFirst().get()
  }
}

private enum TestKeychainError: Error {
  case readFailed
  case writeFailed
  case deleteFailed
}
