//
//  SharedSessionLocalIdentityStore.swift
//  Clerk
//

import Foundation

typealias SharedSessionLocalIdentity = ClerkIdentitySnapshot

struct SharedSessionLocalIdentityRecord: Codable, Equatable {
  static let schemaVersion = 1

  let schemaVersion: Int
  let acceptedIdentity: SharedSessionLocalIdentity?
  let pendingPublication: SharedSessionIdentityEvent?

  init(
    acceptedIdentity: SharedSessionLocalIdentity?,
    pendingPublication: SharedSessionIdentityEvent?
  ) {
    schemaVersion = Self.schemaVersion
    self.acceptedIdentity = acceptedIdentity
    self.pendingPublication = pendingPublication
  }

  func validated() throws -> Self {
    guard schemaVersion == Self.schemaVersion else {
      throw SharedSessionLocalIdentityStoreError.unsupportedSchemaVersion
    }
    _ = try acceptedIdentity?.validated()
    _ = try pendingPublication?.validated()
    return self
  }
}

enum SharedSessionLocalIdentityStoreError: Error, Equatable {
  case unsupportedSchemaVersion
  case pendingPublicationAlreadyExists
  case pendingPublicationMismatch
}

protocol SharedSessionLocalIdentityStoring: Sendable {
  func loadRecord() throws -> SharedSessionLocalIdentityRecord?
  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws
  func invalidateOperations(through operationRevision: UInt64) throws
  func save(
    _ identity: SharedSessionLocalIdentity,
    operationRevision: UInt64
  ) throws -> Bool
  func delete(operationRevision: UInt64) throws -> Bool
  func deleteInvalidatingOperations(through operationRevision: UInt64) throws
}

extension SharedSessionLocalIdentityStoring {
  func load() throws -> SharedSessionLocalIdentity? {
    try loadRecord()?.acceptedIdentity
  }

  func loadPendingPublication() throws -> SharedSessionIdentityEvent? {
    try loadRecord()?.pendingPublication
  }

  func save(_ identity: SharedSessionLocalIdentity) throws {
    let identity = try identity.validated()
    try updateRecord { record in
      guard record?.pendingPublication == nil else {
        throw SharedSessionLocalIdentityStoreError.pendingPublicationAlreadyExists
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: identity,
        pendingPublication: nil
      )
    }
  }

  func stagePendingPublication(_ event: SharedSessionIdentityEvent) throws {
    let event = try event.validated()
    try updateRecord { record in
      if record?.pendingPublication == event {
        return record
      }
      guard record?.pendingPublication == nil else {
        throw SharedSessionLocalIdentityStoreError.pendingPublicationAlreadyExists
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: record?.acceptedIdentity,
        pendingPublication: event
      )
    }
  }

  func commitAcceptedIdentity(
    _ identity: SharedSessionLocalIdentity,
    clearingPendingPublicationID pendingPublicationID: UUID
  ) throws {
    let identity = try identity.validated()
    try updateRecord { record in
      guard record?.pendingPublication?.id == pendingPublicationID else {
        throw SharedSessionLocalIdentityStoreError.pendingPublicationMismatch
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: identity,
        pendingPublication: nil
      )
    }
  }

  func clearPendingPublication() throws {
    try updateRecord { record in
      guard let record, record.pendingPublication != nil else {
        return record
      }
      guard let acceptedIdentity = record.acceptedIdentity else {
        return nil
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: acceptedIdentity,
        pendingPublication: nil
      )
    }
  }

  func delete() throws {
    try updateRecord { _ in nil }
  }

  func invalidateOperations(through _: UInt64) throws {}

  func save(
    _ identity: SharedSessionLocalIdentity,
    operationRevision _: UInt64
  ) throws -> Bool {
    try save(identity)
    return true
  }

  func delete(operationRevision _: UInt64) throws -> Bool {
    try delete()
    return true
  }

  func deleteInvalidatingOperations(through operationRevision: UInt64) throws {
    try invalidateOperations(through: operationRevision)
    try delete()
  }
}

struct SharedSessionLocalIdentityStore: SharedSessionLocalIdentityStoring {
  static let storageKey = "clerkSharedSessionLocalIdentityV2"

  private struct RecordHeader: Decodable {
    let schemaVersion: Int?
  }

  private final class State: @unchecked Sendable {
    let lock = NSLock()
    var latestOperationRevision: UInt64 = 0
  }

  private let keychain: any KeychainStorage
  private let state = State()

  init(keychain: any KeychainStorage) {
    self.keychain = keychain
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    state.lock.lock()
    defer { state.lock.unlock() }
    return try loadRecordWithoutLocking()
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    state.lock.lock()
    defer { state.lock.unlock() }
    try updateRecordWithoutLocking(update)
  }

  func invalidateOperations(through operationRevision: UInt64) throws {
    state.lock.lock()
    defer { state.lock.unlock() }
    state.latestOperationRevision = max(
      state.latestOperationRevision,
      operationRevision
    )
  }

  func save(
    _ identity: SharedSessionLocalIdentity,
    operationRevision: UInt64
  ) throws -> Bool {
    let identity = try identity.validated()
    state.lock.lock()
    defer { state.lock.unlock() }
    guard operationRevision > state.latestOperationRevision else { return false }
    state.latestOperationRevision = operationRevision
    try updateRecordWithoutLocking { record in
      guard record?.pendingPublication == nil else {
        throw SharedSessionLocalIdentityStoreError.pendingPublicationAlreadyExists
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: identity,
        pendingPublication: nil
      )
    }
    return true
  }

  func delete(operationRevision: UInt64) throws -> Bool {
    state.lock.lock()
    defer { state.lock.unlock() }
    guard operationRevision > state.latestOperationRevision else { return false }
    state.latestOperationRevision = operationRevision
    try keychain.deleteItem(forKey: Self.storageKey)
    return true
  }

  func deleteInvalidatingOperations(through operationRevision: UInt64) throws {
    state.lock.lock()
    defer { state.lock.unlock() }
    state.latestOperationRevision = max(
      state.latestOperationRevision,
      operationRevision
    )
    try keychain.deleteItem(forKey: Self.storageKey)
  }

  private func updateRecordWithoutLocking(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    let current = try loadRecordWithoutLocking()
    guard let updated = try update(current) else {
      try keychain.deleteItem(forKey: Self.storageKey)
      return
    }
    let validated = try updated.validated()
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(validated),
      forKey: Self.storageKey
    )
  }

  private func loadRecordWithoutLocking() throws -> SharedSessionLocalIdentityRecord? {
    guard let data = try keychain.data(forKey: Self.storageKey) else {
      return nil
    }

    let decoder = JSONDecoder.clerkDecoder
    if try decoder.decode(RecordHeader.self, from: data).schemaVersion != nil {
      return try decoder
        .decode(SharedSessionLocalIdentityRecord.self, from: data)
        .validated()
    }

    let legacyIdentity = try decoder
      .decode(SharedSessionLocalIdentity.self, from: data)
      .validated()
    return SharedSessionLocalIdentityRecord(
      acceptedIdentity: legacyIdentity,
      pendingPublication: nil
    )
  }
}

actor SharedSessionLocalIdentityIO {
  private let store: any SharedSessionLocalIdentityStoring
  private var latestOperationRevision: UInt64 = 0

  init(store: any SharedSessionLocalIdentityStoring) {
    self.store = store
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    try store.loadRecord()
  }

  func stagePendingPublication(_ event: SharedSessionIdentityEvent) throws {
    try store.stagePendingPublication(event)
  }

  func saveAcceptedIdentity(_ identity: SharedSessionLocalIdentity) throws {
    try store.save(identity)
  }

  func saveAcceptedIdentity(
    _ identity: SharedSessionLocalIdentity,
    operationRevision: UInt64
  ) throws -> Bool {
    guard operationRevision > latestOperationRevision else { return false }
    latestOperationRevision = operationRevision
    return try store.save(identity, operationRevision: operationRevision)
  }

  func invalidateOperations(through operationRevision: UInt64) throws {
    latestOperationRevision = max(latestOperationRevision, operationRevision)
    try store.invalidateOperations(through: operationRevision)
  }

  func delete(operationRevision: UInt64) throws -> Bool {
    guard operationRevision > latestOperationRevision else { return false }
    latestOperationRevision = operationRevision
    return try store.delete(operationRevision: operationRevision)
  }

  func delete() throws {
    latestOperationRevision &+= 1
    _ = try store.delete(operationRevision: latestOperationRevision)
  }

  func commitAcceptedIdentity(
    _ identity: SharedSessionLocalIdentity,
    clearingPendingPublicationID pendingPublicationID: UUID
  ) throws {
    try store.commitAcceptedIdentity(
      identity,
      clearingPendingPublicationID: pendingPublicationID
    )
  }

  func clearPendingPublication() throws {
    try store.clearPendingPublication()
  }
}
