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

  func preventLegacyIdentityReadoption(
    for intent: SharedSessionOwnerSlotClearRecovery.Intent
  ) throws
}

enum SharedSessionOwnerSlotClearRecovery {
  static let storageKey = "clerkSharedSessionOwnerSlotClearIntentV1"

  struct Intent: Codable, Equatable {
    static let schemaVersion = 2
    static let legacySchemaVersion = 1

    let schemaVersion: Int
    let localIdentityService: String
    let localIdentityAccessGroup: String?
    let slotService: String
    let slotAccessGroup: String
    let slotAccount: String
    let instanceFingerprint: String
    let ownerIdentifier: String

    init(
      localIdentityService: String,
      localIdentityAccessGroup: String? = nil,
      slotService: String,
      slotAccessGroup: String,
      slotAccount: String,
      instanceFingerprint: String,
      ownerIdentifier: String
    ) {
      schemaVersion = localIdentityAccessGroup == nil
        ? Self.legacySchemaVersion
        : Self.schemaVersion
      self.localIdentityService = localIdentityService
      self.localIdentityAccessGroup = localIdentityAccessGroup
      self.slotService = slotService
      self.slotAccessGroup = slotAccessGroup
      self.slotAccount = slotAccount
      self.instanceFingerprint = instanceFingerprint
      self.ownerIdentifier = ownerIdentifier
    }

    func validated() throws -> Self {
      guard schemaVersion == Self.legacySchemaVersion
        || schemaVersion == Self.schemaVersion
      else {
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
      if let localIdentityAccessGroup {
        guard schemaVersion == Self.schemaVersion,
              !localIdentityAccessGroup.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              AppLocalKeychainAccessGroup.isApplicationIdentifier(
                localIdentityAccessGroup,
                for: ownerIdentifier
              ),
              localIdentityAccessGroup != slotAccessGroup
        else {
          throw SharedSessionOwnerSlotClearRecoveryError.invalidIntent
        }
      } else if schemaVersion == Self.schemaVersion {
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
      try SharedSessionLocalIdentityStore(
        keychain: localIdentityKeychain(for: intent)
      )
    }

    func slotStore(
      for intent: Intent
    ) throws -> any SharedSessionSlotStoring {
      try SharedSessionOwnerSlotStore(clearRecoveryIntent: intent)
    }

    func preventLegacyIdentityReadoption(for intent: Intent) throws {
      try localIdentityKeychain(for: intent).set(
        SharedSessionSyncAdoption.markerValue,
        forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      )
    }

    private func localIdentityKeychain(
      for intent: Intent
    ) throws -> any KeychainStorage {
      let intent = try intent.validated()
      if let accessGroup = intent.localIdentityAccessGroup {
        return ApplicationKeychainStorage.make(
          service: intent.localIdentityService,
          accessGroup: accessGroup,
          migrateLegacyUnscopedItems: false
        )
      }
      // Version 1 intents predate explicit app-local scoping. This broad
      // access is retained only to finish the already-durable clear.
      return SystemKeychain(service: intent.localIdentityService)
    }
  }

  static func liveContext(
    ownerIdentifier: String?,
    currentIntent: Intent?,
    appLocalAccessGroup: String? = nil
  ) -> Context? {
    guard let ownerIdentifier = ownerIdentifier?.trimmingCharacters(
      in: .whitespacesAndNewlines
    ), !ownerIdentifier.isEmpty else {
      return nil
    }
    let journalService = journalService(ownerIdentifier: ownerIdentifier)
    let journal: any KeychainStorage = if let appLocalAccessGroup {
      ApplicationKeychainStorage.make(
        service: journalService,
        accessGroup: appLocalAccessGroup,
        migrateLegacyUnscopedItems: true
      )
    } else {
      SystemKeychain(service: journalService)
    }
    return Context(
      journal: journal,
      currentIntent: currentIntent,
      targetProvider: LiveTargetProvider()
    )
  }

  static func journalService(ownerIdentifier: String) -> String {
    "\(ownerIdentifier).clerk.shared-session-clear-recovery.v1"
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

    try context.targetProvider.preventLegacyIdentityReadoption(for: intent)
    if let currentIntent = context.currentIntent,
       currentIntent != intent
    {
      try context.targetProvider.preventLegacyIdentityReadoption(
        for: currentIntent
      )
    }
    try context.targetProvider.slotStore(for: intent).deleteOwnSlot()
    try context.targetProvider.localIdentityStore(for: intent).delete()
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
