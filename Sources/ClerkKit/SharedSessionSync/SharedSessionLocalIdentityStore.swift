//
//  SharedSessionLocalIdentityStore.swift
//  Clerk
//

import Foundation

typealias SharedSessionLocalIdentity = ClerkIdentitySnapshot

struct SharedSessionPendingAuthFlowCompletion: Codable, Equatable {
  private enum Flow: Codable, Equatable {
    case signIn(SignIn)
    case signUp(SignUp)
  }

  let eventID: UUID
  private let flow: Flow

  private enum CodingKeys: String, CodingKey {
    case eventID = "eventId"
    case flow
  }

  init(eventID: UUID, result: TransferFlowResult) {
    self.eventID = eventID
    switch result {
    case .signIn(let signIn):
      flow = .signIn(signIn)
    case .signUp(let signUp):
      flow = .signUp(signUp)
    }
  }

  var result: TransferFlowResult {
    switch flow {
    case .signIn(let signIn):
      .signIn(signIn)
    case .signUp(let signUp):
      .signUp(signUp)
    }
  }
}

struct SharedSessionLocalIdentityRecord: Codable, Equatable {
  static let schemaVersion = 1

  let schemaVersion: Int
  let acceptedIdentity: SharedSessionLocalIdentity?
  let pendingPublication: SharedSessionIdentityEvent?
  let pendingAuthFlowCompletion: SharedSessionPendingAuthFlowCompletion?
  let requiresSharedSessionPublication: Bool

  init(
    acceptedIdentity: SharedSessionLocalIdentity?,
    pendingPublication: SharedSessionIdentityEvent?,
    pendingAuthFlowCompletion: SharedSessionPendingAuthFlowCompletion? = nil,
    requiresSharedSessionPublication: Bool = false
  ) {
    schemaVersion = Self.schemaVersion
    self.acceptedIdentity = acceptedIdentity
    self.pendingPublication = pendingPublication
    self.pendingAuthFlowCompletion = pendingAuthFlowCompletion
    self.requiresSharedSessionPublication = requiresSharedSessionPublication
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case acceptedIdentity
    case pendingPublication
    case pendingAuthFlowCompletion
    case requiresSharedSessionPublication = "requiresLegacyAdoptionPublication"
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    acceptedIdentity = try container.decodeIfPresent(
      SharedSessionLocalIdentity.self,
      forKey: .acceptedIdentity
    )
    pendingPublication = try container.decodeIfPresent(
      SharedSessionIdentityEvent.self,
      forKey: .pendingPublication
    )
    pendingAuthFlowCompletion = try container.decodeIfPresent(
      SharedSessionPendingAuthFlowCompletion.self,
      forKey: .pendingAuthFlowCompletion
    )
    requiresSharedSessionPublication = try container.decodeIfPresent(
      Bool.self,
      forKey: .requiresSharedSessionPublication
    ) ?? false
  }

  func validated() throws -> Self {
    guard schemaVersion == Self.schemaVersion else {
      throw SharedSessionLocalIdentityStoreError.unsupportedSchemaVersion
    }
    guard !requiresSharedSessionPublication || acceptedIdentity != nil else {
      throw SharedSessionLocalIdentityStoreError.missingRequiredPublicationIdentity
    }
    guard pendingPublication == nil ||
      pendingAuthFlowCompletion == nil ||
      pendingPublication?.id == pendingAuthFlowCompletion?.eventID
    else {
      throw SharedSessionLocalIdentityStoreError.pendingAuthFlowCompletionMismatch
    }
    _ = try acceptedIdentity?.validated()
    _ = try pendingPublication?.validated()
    return self
  }

  func pendingTokenOnlyPublicationEventID(for ownerIdentifier: String) -> UUID? {
    guard requiresSharedSessionPublication,
          let acceptedIdentity,
          acceptedIdentity.state == .cleared,
          acceptedIdentity.deviceToken.nilIfEmpty != nil,
          acceptedIdentity.client == nil,
          let pendingPublication,
          pendingPublication.originOwnerIdentifier == ownerIdentifier,
          SharedSessionLocalIdentity(
            state: pendingPublication.state,
            deviceToken: pendingPublication.deviceToken,
            client: pendingPublication.client,
            serverDate: pendingPublication.serverDate
          ) == acceptedIdentity
    else {
      return nil
    }
    return pendingPublication.id
  }
}

enum SharedSessionLocalIdentityStoreError: Error, Equatable {
  case unsupportedSchemaVersion
  case missingRequiredPublicationIdentity
  case pendingPublicationAlreadyExists
  case pendingPublicationMismatch
  case pendingAuthFlowCompletionMismatch
}

protocol SharedSessionLocalIdentityStoring: Sendable {
  func loadRecord() throws -> SharedSessionLocalIdentityRecord?
  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws
  func invalidateOperations(through operationRevision: UInt64) throws
  /// Saves an authoritative atomic-local transition, superseding any orphaned shared publication.
  func save(
    _ identity: SharedSessionLocalIdentity,
    operationRevision: UInt64,
    requiresSharedSessionPublication: Bool
  ) throws -> Bool
  func delete(operationRevision: UInt64) throws -> Bool
  func deleteInvalidatingOperations(through operationRevision: UInt64) throws
}

extension SharedSessionLocalIdentityStoring {
  func save(
    _ identity: SharedSessionLocalIdentity,
    operationRevision: UInt64
  ) throws -> Bool {
    try save(
      identity,
      operationRevision: operationRevision,
      requiresSharedSessionPublication: false
    )
  }

  func load() throws -> SharedSessionLocalIdentity? {
    try loadRecord()?.acceptedIdentity
  }

  func loadPendingPublication() throws -> SharedSessionIdentityEvent? {
    try loadRecord()?.pendingPublication
  }

  func loadPendingAuthFlowCompletion() throws -> SharedSessionPendingAuthFlowCompletion? {
    try loadRecord()?.pendingAuthFlowCompletion
  }

  func save(_ identity: SharedSessionLocalIdentity) throws {
    let identity = try identity.validated()
    try updateRecord { record in
      guard record?.pendingPublication == nil else {
        throw SharedSessionLocalIdentityStoreError.pendingPublicationAlreadyExists
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: identity,
        pendingPublication: nil,
        pendingAuthFlowCompletion: record?.pendingAuthFlowCompletion
      )
    }
  }

  func saveRequiringSharedSessionPublication(
    _ identity: SharedSessionLocalIdentity
  ) throws {
    let identity = try identity.validated()
    try updateRecord { record in
      guard record?.pendingPublication == nil,
            record?.pendingAuthFlowCompletion == nil
      else {
        throw SharedSessionLocalIdentityStoreError.pendingPublicationAlreadyExists
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: identity,
        pendingPublication: nil,
        requiresSharedSessionPublication: true
      )
    }
  }

  func stagePendingPublication(
    _ event: SharedSessionIdentityEvent,
    completedAuthFlow: TransferFlowResult? = nil
  ) throws {
    let event = try event.validated()
    let pendingAuthFlowCompletion = completedAuthFlow.map {
      SharedSessionPendingAuthFlowCompletion(eventID: event.id, result: $0)
    }
    try updateRecord { record in
      if record?.pendingPublication == event,
         record?.pendingAuthFlowCompletion == pendingAuthFlowCompletion
      {
        return record
      }
      guard record?.pendingPublication == nil,
            record?.pendingAuthFlowCompletion == nil
      else {
        throw SharedSessionLocalIdentityStoreError.pendingPublicationAlreadyExists
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: record?.acceptedIdentity,
        pendingPublication: event,
        pendingAuthFlowCompletion: pendingAuthFlowCompletion,
        requiresSharedSessionPublication:
        record?.requiresSharedSessionPublication ?? false
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
        pendingPublication: nil,
        pendingAuthFlowCompletion: record?.pendingAuthFlowCompletion
      )
    }
  }

  func clearPendingPublication() throws {
    try updateRecord { record in
      guard let record,
            record.pendingPublication != nil ||
            record.pendingAuthFlowCompletion != nil
      else {
        return record
      }
      guard let acceptedIdentity = record.acceptedIdentity else {
        return nil
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: acceptedIdentity,
        pendingPublication: nil,
        requiresSharedSessionPublication:
        record.requiresSharedSessionPublication
      )
    }
  }

  func clearPendingAuthFlowCompletion(eventID: UUID) throws {
    try updateRecord { record in
      guard let record,
            let pendingAuthFlowCompletion = record.pendingAuthFlowCompletion
      else {
        return record
      }
      guard pendingAuthFlowCompletion.eventID == eventID else {
        throw SharedSessionLocalIdentityStoreError.pendingAuthFlowCompletionMismatch
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: record.acceptedIdentity,
        pendingPublication: record.pendingPublication,
        requiresSharedSessionPublication:
        record.requiresSharedSessionPublication
      )
    }
  }

  func delete() throws {
    try updateRecord { _ in nil }
  }

  func invalidateOperations(through _: UInt64) throws {}

  func save(
    _ identity: SharedSessionLocalIdentity,
    operationRevision _: UInt64,
    requiresSharedSessionPublication: Bool
  ) throws -> Bool {
    let identity = try identity.validated()
    try updateRecord { _ in
      SharedSessionLocalIdentityRecord(
        acceptedIdentity: identity,
        pendingPublication: nil,
        requiresSharedSessionPublication:
        requiresSharedSessionPublication
      )
    }
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
    operationRevision: UInt64,
    requiresSharedSessionPublication: Bool
  ) throws -> Bool {
    let identity = try identity.validated()
    state.lock.lock()
    defer { state.lock.unlock() }
    guard operationRevision > state.latestOperationRevision else { return false }
    state.latestOperationRevision = operationRevision
    try updateRecordWithoutLocking { _ in
      SharedSessionLocalIdentityRecord(
        acceptedIdentity: identity,
        pendingPublication: nil,
        requiresSharedSessionPublication:
        requiresSharedSessionPublication
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
      guard current != nil else { return }
      try keychain.deleteItem(forKey: Self.storageKey)
      return
    }
    let validated = try updated.validated()
    guard validated != current else { return }
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

  func stagePendingPublication(
    _ event: SharedSessionIdentityEvent,
    completedAuthFlow: TransferFlowResult? = nil
  ) throws {
    try store.stagePendingPublication(
      event,
      completedAuthFlow: completedAuthFlow
    )
  }

  func saveAcceptedIdentity(_ identity: SharedSessionLocalIdentity) throws {
    try store.save(identity)
  }

  func saveAcceptedIdentity(
    _ identity: SharedSessionLocalIdentity,
    operationRevision: UInt64,
    requiresSharedSessionPublication: Bool = false
  ) throws -> Bool {
    guard operationRevision > latestOperationRevision else { return false }
    latestOperationRevision = operationRevision
    return try store.save(
      identity,
      operationRevision: operationRevision,
      requiresSharedSessionPublication: requiresSharedSessionPublication
    )
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

  func clearPendingAuthFlowCompletion(eventID: UUID) throws {
    try store.clearPendingAuthFlowCompletion(eventID: eventID)
  }
}
