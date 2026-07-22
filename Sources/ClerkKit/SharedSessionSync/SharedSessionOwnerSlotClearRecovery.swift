//
//  SharedSessionOwnerSlotClearRecovery.swift
//  Clerk
//

import Foundation

enum SharedSessionOwnerSlotClearRecoveryError: Error, Equatable {
  case unsupportedSchemaVersion
  case invalidIntent
  case missingCurrentTopology
  case pendingIntentConflict
}

protocol SharedSessionClearRecoveryTargets: Sendable {
  func localIdentityStore(
    for intent: SharedSessionOwnerSlotClearRecovery.Intent
  ) throws -> any SharedSessionLocalIdentityStoring

  func slotStore(
    for intent: SharedSessionOwnerSlotClearRecovery.Intent
  ) throws -> any SharedSessionSlotStoring
}

enum SharedSessionOwnerSlotClearRecovery {
  static let storageKey = "clerkSharedSessionOwnerSlotClearIntentV1"

  struct Intent: Codable, Equatable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let localIdentityService: String
    let slotService: String
    let slotAccessGroup: String
    let slotAccount: String
    let instanceFingerprint: String
    let ownerIdentifier: String

    init(
      localIdentityService: String,
      slotService: String,
      slotAccessGroup: String,
      slotAccount: String,
      instanceFingerprint: String,
      ownerIdentifier: String
    ) {
      schemaVersion = Self.schemaVersion
      self.localIdentityService = localIdentityService
      self.slotService = slotService
      self.slotAccessGroup = slotAccessGroup
      self.slotAccount = slotAccount
      self.instanceFingerprint = instanceFingerprint
      self.ownerIdentifier = ownerIdentifier
    }

    func validated() throws -> Self {
      guard schemaVersion == Self.schemaVersion else {
        throw SharedSessionOwnerSlotClearRecoveryError.unsupportedSchemaVersion
      }
      let requiredValues = [
        localIdentityService,
        slotService,
        slotAccessGroup,
        slotAccount,
        instanceFingerprint,
        ownerIdentifier,
      ]
      guard requiredValues.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
        throw SharedSessionOwnerSlotClearRecoveryError.invalidIntent
      }
      return self
    }
  }

  struct Context {
    let journal: any KeychainStorage
    let currentIntent: Intent?
    let targetProvider: any SharedSessionClearRecoveryTargets
  }

  struct LiveTargetProvider: SharedSessionClearRecoveryTargets {
    func localIdentityStore(
      for intent: Intent
    ) throws -> any SharedSessionLocalIdentityStoring {
      let intent = try intent.validated()
      return SharedSessionLocalIdentityStore(
        keychain: SystemKeychain(service: intent.localIdentityService)
      )
    }

    func slotStore(
      for intent: Intent
    ) throws -> any SharedSessionSlotStoring {
      try SharedSessionOwnerSlotStore(clearRecoveryIntent: intent)
    }
  }

  static func liveContext(
    ownerIdentifier: String?,
    currentIntent: Intent?
  ) -> Context? {
    guard let ownerIdentifier = ownerIdentifier?.trimmingCharacters(
      in: .whitespacesAndNewlines
    ), !ownerIdentifier.isEmpty else {
      return nil
    }
    return Context(
      journal: SystemKeychain(
        service: "\(ownerIdentifier).clerk.shared-session-clear-recovery.v1"
      ),
      currentIntent: currentIntent,
      targetProvider: LiveTargetProvider()
    )
  }

  static func markPending(in context: Context) throws {
    guard let intent = try context.currentIntent?.validated() else {
      throw SharedSessionOwnerSlotClearRecoveryError.missingCurrentTopology
    }
    if let pending = try loadPendingIntent(in: context.journal) {
      guard pending == intent else {
        throw SharedSessionOwnerSlotClearRecoveryError.pendingIntentConflict
      }
      return
    }
    try context.journal.set(
      JSONEncoder.clerkEncoder.encode(intent),
      forKey: storageKey
    )
  }

  static func clearPendingIntent(
    matching expectedIntent: Intent,
    in context: Context
  ) throws {
    guard let pending = try loadPendingIntent(in: context.journal) else {
      return
    }
    guard pending == expectedIntent else {
      throw SharedSessionOwnerSlotClearRecoveryError.pendingIntentConflict
    }
    try context.journal.deleteItem(forKey: storageKey)
  }

  @discardableResult
  static func recoverIfNeeded(in context: Context?) throws -> Bool {
    guard let context,
          let intent = try loadPendingIntent(in: context.journal)
    else {
      return false
    }

    try context.targetProvider.localIdentityStore(for: intent).delete()
    try context.targetProvider.slotStore(for: intent).deleteOwnSlot()
    try context.journal.deleteItem(forKey: storageKey)
    return true
  }

  static func loadPendingIntent(
    in journal: any KeychainStorage
  ) throws -> Intent? {
    guard let data = try journal.data(forKey: storageKey) else { return nil }
    return try JSONDecoder.clerkDecoder.decode(Intent.self, from: data).validated()
  }
}
