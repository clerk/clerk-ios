//
//  AppContainerIdentityClearIntent.swift
//  Clerk
//

import Foundation

enum AppContainerIdentityClearIntentError: Error, Equatable {
  case applicationSupportDirectoryUnavailable
  case invalidIntent
  case pendingIntentConflict
  case runtimePersistenceRoutingRequiresRestart
  case unsupportedSchemaVersion
}

struct AppContainerIdentityClearIntent: Codable, Equatable {
  static let schemaVersion = 1

  struct KeychainTarget: Codable, Equatable, Hashable {
    enum Kind: String, Codable {
      case applicationLocal
      case configured
    }

    let kind: Kind
    let service: String
    let accessGroup: String?
    let legacyAccessGroups: [String]

    func validated(ownerIdentifier: String?) throws -> Self {
      switch kind {
      case .configured:
        guard legacyAccessGroups.isEmpty else {
          throw AppContainerIdentityClearIntentError.invalidIntent
        }
        if let accessGroup {
          guard accessGroup
            == accessGroup.trimmingCharacters(
              in: .whitespacesAndNewlines
            ),
            !accessGroup.isEmpty
          else {
            throw AppContainerIdentityClearIntentError.invalidIntent
          }
        }
      case .applicationLocal:
        guard let accessGroup,
              !accessGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              accessGroup
              == accessGroup.trimmingCharacters(
                in: .whitespacesAndNewlines
              ),
              !accessGroup.hasPrefix("group.")
        else {
          throw AppContainerIdentityClearIntentError.invalidIntent
        }
        if let ownerIdentifier {
          guard AppLocalKeychainAccessGroup.isApplicationIdentifier(
            accessGroup,
            for: ownerIdentifier
          ) else {
            throw AppContainerIdentityClearIntentError.invalidIntent
          }
        }
        guard legacyAccessGroups.allSatisfy({
          !$0.isEmpty
            && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines)
            && $0 != accessGroup
        }) else {
          throw AppContainerIdentityClearIntentError.invalidIntent
        }
      }

      return self
    }

    func makeStorage() -> any KeychainStorage {
      switch kind {
      case .configured:
        DependencyContainer.makeKeychainStorage(
          service: service,
          accessGroup: accessGroup
        )
      case .applicationLocal:
        ApplicationKeychainStorage.make(
          service: service,
          accessGroup: accessGroup!,
          migrateLegacyUnscopedItems: true,
          legacyAccessGroups: legacyAccessGroups
        )
      }
    }
  }

  let schemaVersion: Int
  let transactionID: UUID
  let instanceFingerprint: String
  let ownerIdentifier: String?
  let configuredShared: KeychainTarget
  let configuredAppLocal: KeychainTarget
  let stableIdentity: KeychainTarget
  let previousAppLocal: KeychainTarget?
  let clearJournal: KeychainTarget?
  let ownerSlot: SharedSessionOwnerSlotClearRecovery.Intent?

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case transactionID = "transactionId"
    case instanceFingerprint
    case ownerIdentifier
    case configuredShared
    case configuredAppLocal
    case stableIdentity
    case previousAppLocal
    case clearJournal
    case ownerSlot
  }

  init(
    transactionID: UUID = UUID(),
    instanceFingerprint: String,
    ownerIdentifier: String?,
    configuredShared: KeychainTarget,
    configuredAppLocal: KeychainTarget,
    stableIdentity: KeychainTarget,
    previousAppLocal: KeychainTarget?,
    clearJournal: KeychainTarget?,
    ownerSlot: SharedSessionOwnerSlotClearRecovery.Intent?
  ) {
    schemaVersion = Self.schemaVersion
    self.transactionID = transactionID
    self.instanceFingerprint = instanceFingerprint
    self.ownerIdentifier = ownerIdentifier
    self.configuredShared = configuredShared
    self.configuredAppLocal = configuredAppLocal
    self.stableIdentity = stableIdentity
    self.previousAppLocal = previousAppLocal
    self.clearJournal = clearJournal
    self.ownerSlot = ownerSlot
  }

  func validated() throws -> Self {
    guard schemaVersion == Self.schemaVersion else {
      throw AppContainerIdentityClearIntentError.unsupportedSchemaVersion
    }
    guard instanceFingerprint.count == 64,
          instanceFingerprint.allSatisfy(\.isHexDigit)
    else {
      throw AppContainerIdentityClearIntentError.invalidIntent
    }
    let ownerIdentifier = ownerIdentifier?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if self.ownerIdentifier != nil,
       ownerIdentifier?.isEmpty != false
       || self.ownerIdentifier != ownerIdentifier
    {
      throw AppContainerIdentityClearIntentError.invalidIntent
    }

    _ = try configuredShared.validated(ownerIdentifier: nil)
    _ = try configuredAppLocal.validated(ownerIdentifier: ownerIdentifier)
    _ = try stableIdentity.validated(ownerIdentifier: ownerIdentifier)
    _ = try previousAppLocal?.validated(ownerIdentifier: ownerIdentifier)
    _ = try clearJournal?.validated(ownerIdentifier: ownerIdentifier)

    guard configuredShared.kind == .configured,
          configuredAppLocal.service == configuredShared.service
    else {
      throw AppContainerIdentityClearIntentError.invalidIntent
    }
    let expectedLegacyAccessGroups =
      configuredShared.accessGroup.map { [$0] } ?? []
    let hasPrivateAppLocalTopology: Bool
    switch configuredAppLocal.kind {
    case .configured:
      guard configuredAppLocal == configuredShared else {
        throw AppContainerIdentityClearIntentError.invalidIntent
      }
      hasPrivateAppLocalTopology = false
    case .applicationLocal:
      guard configuredAppLocal.accessGroup != configuredShared.accessGroup,
            configuredAppLocal.legacyAccessGroups
            == expectedLegacyAccessGroups
      else {
        throw AppContainerIdentityClearIntentError.invalidIntent
      }
      hasPrivateAppLocalTopology = true
    }

    func expectedAppLocalTarget(
      service: String
    ) -> KeychainTarget {
      if hasPrivateAppLocalTopology {
        return KeychainTarget(
          kind: .applicationLocal,
          service: service,
          accessGroup: configuredAppLocal.accessGroup,
          legacyAccessGroups: expectedLegacyAccessGroups
        )
      }
      return KeychainTarget(
        kind: .configured,
        service: service,
        accessGroup: service == configuredShared.service
          ? configuredShared.accessGroup
          : nil,
        legacyAccessGroups: []
      )
    }

    if let ownerSlot {
      let ownerSlot = try ownerSlot.validated()
      guard ownerSlot.instanceFingerprint == instanceFingerprint,
            ownerSlot.ownerIdentifier == ownerIdentifier,
            ownerSlot.localIdentityService
            == DependencyContainer.stableIdentityService(
              configuredService: configuredShared.service,
              instanceFingerprint: instanceFingerprint,
              ownerIdentifier: ownerSlot.ownerIdentifier
            ),
            ownerSlot.slotService
            == SharedSessionOwnerSlotStore.service(
              configuredService: configuredShared.service,
              instanceFingerprint: instanceFingerprint
            ),
            ownerSlot.slotAccessGroup == configuredShared.accessGroup,
            ownerSlot.slotAccount
            == SharedSessionOwnerSlotStore.account(
              instanceFingerprint: instanceFingerprint,
              ownerIdentifier: ownerSlot.ownerIdentifier
            ),
            clearJournal
            == expectedAppLocalTarget(
              service: SharedSessionOwnerSlotClearRecovery.journalService(
                ownerIdentifier: ownerSlot.ownerIdentifier
              )
            )
      else {
        throw AppContainerIdentityClearIntentError.invalidIntent
      }
      let expectedStableIdentity: KeychainTarget
      if let localIdentityAccessGroup =
        ownerSlot.localIdentityAccessGroup
      {
        guard hasPrivateAppLocalTopology,
              configuredAppLocal.accessGroup
              == localIdentityAccessGroup
        else {
          throw AppContainerIdentityClearIntentError.invalidIntent
        }
        expectedStableIdentity = KeychainTarget(
          kind: .applicationLocal,
          service: ownerSlot.localIdentityService,
          accessGroup: localIdentityAccessGroup,
          legacyAccessGroups: expectedLegacyAccessGroups
        )
      } else {
        expectedStableIdentity = KeychainTarget(
          kind: .configured,
          service: ownerSlot.localIdentityService,
          accessGroup: nil,
          legacyAccessGroups: []
        )
      }
      guard stableIdentity == expectedStableIdentity else {
        throw AppContainerIdentityClearIntentError.invalidIntent
      }
    } else {
      let expectedStableService =
        DependencyContainer.stableIdentityService(
          configuredService: configuredShared.service,
          instanceFingerprint: instanceFingerprint,
          ownerIdentifier: ownerIdentifier
        )
      guard clearJournal == nil,
            stableIdentity
            == expectedAppLocalTarget(service: expectedStableService)
      else {
        throw AppContainerIdentityClearIntentError.invalidIntent
      }
    }

    let expectedPreviousAppLocal: KeychainTarget? =
      if let ownerIdentifier,
      ownerIdentifier != configuredShared.service {
        expectedAppLocalTarget(service: ownerIdentifier)
      } else {
        nil
      }
    guard previousAppLocal == expectedPreviousAppLocal else {
      throw AppContainerIdentityClearIntentError.invalidIntent
    }

    return self
  }

  var uniqueAppLocalKeychainTargets: [KeychainTarget] {
    uniqueTargets(
      from: [
        stableIdentity,
        configuredAppLocal,
        previousAppLocal,
      ]
    )
  }

  var uniqueKeychainTargets: [KeychainTarget] {
    uniqueTargets(
      from: [
        stableIdentity,
        configuredAppLocal,
        previousAppLocal,
        configuredShared,
      ]
    )
  }

  private func uniqueTargets(
    from targets: [KeychainTarget?]
  ) -> [KeychainTarget] {
    var seen = Set<KeychainTarget>()
    return targets.compactMap { target in
      guard let target, seen.insert(target).inserted else { return nil }
      return target
    }
  }

  func hasSameRecoveryTopology(
    as other: AppContainerIdentityClearIntent
  ) -> Bool {
    instanceFingerprint == other.instanceFingerprint
      && ownerIdentifier == other.ownerIdentifier
      && configuredShared == other.configuredShared
      && configuredAppLocal == other.configuredAppLocal
      && stableIdentity == other.stableIdentity
      && previousAppLocal == other.previousAppLocal
      && clearJournal == other.clearJournal
      && ownerSlot == other.ownerSlot
  }
}

@MainActor
protocol AppContainerIdentityClearIntentStoring: AnyObject {
  func load() throws -> AppContainerIdentityClearIntent?
  func record(_ intent: AppContainerIdentityClearIntent) throws
  func remove(matching transactionID: UUID) throws
}

@MainActor
enum AppContainerIdentityClearIntentStoreFactory {
  static func makeDefault() -> any AppContainerIdentityClearIntentStoring {
    if EnvironmentDetection.isRunningInTests {
      return InMemoryAppContainerIdentityClearIntentStore()
    }
    do {
      return try FileAppContainerIdentityClearIntentStore.live()
    } catch {
      return UnavailableAppContainerIdentityClearIntentStore(error: error)
    }
  }
}

@MainActor
private final class UnavailableAppContainerIdentityClearIntentStore:
  AppContainerIdentityClearIntentStoring
{
  private let error: any Error

  init(error: any Error) {
    self.error = error
  }

  func load() throws -> AppContainerIdentityClearIntent? {
    throw error
  }

  func record(_: AppContainerIdentityClearIntent) throws {
    throw error
  }

  func remove(matching _: UUID) throws {
    throw error
  }
}

@MainActor
final class InMemoryAppContainerIdentityClearIntentStore:
  AppContainerIdentityClearIntentStoring
{
  private(set) var intent: AppContainerIdentityClearIntent?

  init(intent: AppContainerIdentityClearIntent? = nil) {
    self.intent = intent
  }

  func load() throws -> AppContainerIdentityClearIntent? {
    intent
  }

  func record(_ intent: AppContainerIdentityClearIntent) throws {
    let intent = try intent.validated()
    if let pending = self.intent {
      guard pending == intent else {
        throw AppContainerIdentityClearIntentError.pendingIntentConflict
      }
      return
    }
    self.intent = intent
  }

  func remove(matching transactionID: UUID) throws {
    guard let intent else { return }
    guard intent.transactionID == transactionID else {
      throw AppContainerIdentityClearIntentError.pendingIntentConflict
    }
    self.intent = nil
  }
}

@MainActor
final class FileAppContainerIdentityClearIntentStore:
  AppContainerIdentityClearIntentStoring
{
  let fileURL: URL

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  static func live() throws -> FileAppContainerIdentityClearIntentStore {
    guard let applicationSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      throw AppContainerIdentityClearIntentError
        .applicationSupportDirectoryUnavailable
    }

    let applicationIdentifier =
      Bundle.main.bundleIdentifier
        ?? Bundle.main.bundleURL.standardizedFileURL.path
    let applicationDirectory = SharedSessionNamespace.sha256(
      applicationIdentifier
    )
    let fileURL = applicationSupport
      .appendingPathComponent("Clerk", isDirectory: true)
      .appendingPathComponent(applicationDirectory, isDirectory: true)
      .appendingPathComponent("identity-clear", isDirectory: true)
      .appendingPathComponent("pending-v1.json", isDirectory: false)
    return FileAppContainerIdentityClearIntentStore(fileURL: fileURL)
  }

  func load() throws -> AppContainerIdentityClearIntent? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return nil
    }
    let data = try Data(contentsOf: fileURL)
    return try JSONDecoder.clerkDecoder
      .decode(AppContainerIdentityClearIntent.self, from: data)
      .validated()
  }

  func record(_ intent: AppContainerIdentityClearIntent) throws {
    let intent = try intent.validated()
    if let pending = try load() {
      guard pending == intent else {
        throw AppContainerIdentityClearIntentError.pendingIntentConflict
      }
      return
    }

    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let data = try JSONEncoder.clerkEncoder.encode(intent)
    try data.write(to: fileURL, options: .atomic)
    let fileHandle = try FileHandle(forWritingTo: fileURL)
    try fileHandle.synchronize()
    try fileHandle.close()
  }

  func remove(matching transactionID: UUID) throws {
    guard let intent = try load() else { return }
    guard intent.transactionID == transactionID else {
      throw AppContainerIdentityClearIntentError.pendingIntentConflict
    }
    try FileManager.default.removeItem(at: fileURL)
  }
}

@MainActor
struct AppContainerIdentityClearRecovery {
  typealias StorageProvider = @MainActor (
    AppContainerIdentityClearIntent.KeychainTarget
  ) throws -> any KeychainStorage
  typealias SlotStoreProvider = @MainActor (
    SharedSessionOwnerSlotClearRecovery.Intent
  ) throws -> any SharedSessionSlotStoring

  private let storageProvider: StorageProvider
  private let slotStoreProvider: SlotStoreProvider

  init(
    storageProvider: @escaping StorageProvider = { $0.makeStorage() },
    slotStoreProvider: @escaping SlotStoreProvider = {
      try SharedSessionOwnerSlotStore(clearRecoveryIntent: $0)
    }
  ) {
    self.storageProvider = storageProvider
    self.slotStoreProvider = slotStoreProvider
  }

  func recover(_ intent: AppContainerIdentityClearIntent) throws {
    try recover([intent])
  }

  func recover(_ pendingIntents: [AppContainerIdentityClearIntent]) throws {
    let intents = try pendingIntents.map { try $0.validated() }
    var firstError: (any Error)?

    func attempt(_ operation: () throws -> Void) {
      do {
        try operation()
      } catch {
        firstError = firstError ?? error
      }
    }

    func uniqueTargets(
      _ targets: [AppContainerIdentityClearIntent.KeychainTarget]
    ) -> [AppContainerIdentityClearIntent.KeychainTarget] {
      var seen =
        Set<AppContainerIdentityClearIntent.KeychainTarget>()
      return targets.filter { seen.insert($0).inserted }
    }

    let adoptionTargets = uniqueTargets(
      intents.compactMap { intent in
        intent.ownerSlot == nil ? nil : intent.stableIdentity
      }
    )
    for target in adoptionTargets {
      attempt {
        try storageProvider(target).set(
          SharedSessionSyncAdoption.markerValue,
          forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
        )
      }
    }

    let appLocalTargets = uniqueTargets(
      intents.flatMap(\.uniqueAppLocalKeychainTargets)
    )
    var maximumWatchVersion = 0
    for target in appLocalTargets {
      attempt {
        let record: WatchSyncMetadataRecord
        do {
          record = try WatchSyncMetadataStore(
            keychain: storageProvider(target)
          ).load()
        } catch WatchSyncMetadataStoreError.corrupt {
          record = .empty
        }
        maximumWatchVersion = max(
          maximumWatchVersion,
          max(
            record.effectiveDeviceTokenVersion,
            record.effectiveAuthVersion
          )
        )
      }
    }
    guard maximumWatchVersion < Int.max else {
      throw ClerkClientError(
        message: "Watch identity metadata version is exhausted."
      )
    }
    let wallClockWatchVersion = Int(
      Date().timeIntervalSince1970 * 1000
    )
    let minimumWatchClearVersion = max(
      maximumWatchVersion + 1,
      wallClockWatchVersion
    )
    for target in appLocalTargets {
      attempt {
        _ = try WatchSyncMetadataStore(
          keychain: storageProvider(target)
        ).saveClearTombstone(
          minimumVersion: minimumWatchClearVersion
        )
      }
    }

    for intent in intents {
      if let ownerSlot = intent.ownerSlot {
        attempt {
          try slotStoreProvider(ownerSlot).deleteOwnSlot()
        }
      }
    }

    let appLocalTargetSet = Set(appLocalTargets)
    let keychainTargets = uniqueTargets(
      intents.flatMap(\.uniqueKeychainTargets)
    )
    for target in keychainTargets {
      attempt {
        let storage = try storageProvider(target)
        try SharedSessionLocalIdentityStore(keychain: storage).delete()
        var preservedKeys: Set<ClerkKeychainKey> = [
          .sharedSessionSyncAdopted,
        ]
        if appLocalTargetSet.contains(target) {
          preservedKeys.insert(.watchSyncMetadata)
        }
        try Clerk.clearAllKeychainItemsStrictly(
          in: storage,
          preserving: preservedKeys
        )
      }
    }

    if firstError == nil {
      let clearJournals = uniqueTargets(
        intents.compactMap(\.clearJournal)
      )
      for clearJournal in clearJournals {
        attempt {
          try storageProvider(clearJournal).deleteItem(
            forKey: SharedSessionOwnerSlotClearRecovery.storageKey
          )
        }
      }
    }

    if let firstError {
      throw firstError
    }
  }
}

extension Clerk {
  func makeAppContainerIdentityClearIntent()
    throws -> AppContainerIdentityClearIntent
  {
    try Self.makeAppContainerIdentityClearIntent(
      dependencies: dependencies,
      options: options,
      frontendApiUrl: frontendApiUrl,
      publishableKey: publishableKey
    )
  }

  static func makeAppContainerIdentityClearIntent(
    dependencies: any Dependencies,
    options: Clerk.Options,
    frontendApiUrl: String,
    publishableKey: String
  ) throws -> AppContainerIdentityClearIntent {
    let keychainConfig = options.keychainConfig
    let capturedOwnerSlot = dependencies
      .sharedSessionOwnerSlotClearRecovery?
      .currentIntent
    let ownerIdentifier =
      capturedOwnerSlot?.ownerIdentifier
        ?? dependencies.sharedSessionOwnerIdentifier
        ?? Bundle.main.bundleIdentifier
    let namespaceFingerprint = SharedSessionNamespace(
      frontendApiUrl: frontendApiUrl,
      publishableKey: publishableKey
    ).fingerprint
    let appLocalAccessGroup: String? = if let ownerSlotAccessGroup = capturedOwnerSlot?.localIdentityAccessGroup {
      ownerSlotAccessGroup
    } else {
      try AppLocalKeychainAccessGroup.resolve(
        config: keychainConfig,
        ownerIdentifier: ownerIdentifier,
        requiresIsolation: options.sharedSessionSync != nil
      )
    }
    let sharedAccessGroup = keychainConfig.normalizedAccessGroup
    let legacyAccessGroups = sharedAccessGroup.map { [$0] } ?? []
    let ownerSlot: SharedSessionOwnerSlotClearRecovery.Intent? =
      if let capturedOwnerSlot {
        capturedOwnerSlot
      } else if let ownerIdentifier,
                !ownerIdentifier.isEmpty,
                let sharedAccessGroup,
                options.sharedSessionSync != nil
                || (
                  !dependencies.usesVolatileIdentityPersistence
                    && dependencies.atomicIdentityStore != nil
                )
      {
        SharedSessionOwnerSlotClearRecovery.Intent(
          localIdentityService:
          DependencyContainer.stableIdentityService(
            configuredService: keychainConfig.service,
            instanceFingerprint: namespaceFingerprint,
            ownerIdentifier: ownerIdentifier
          ),
          localIdentityAccessGroup: appLocalAccessGroup,
          slotService: SharedSessionOwnerSlotStore.service(
            configuredService: keychainConfig.service,
            instanceFingerprint: namespaceFingerprint
          ),
          slotAccessGroup: sharedAccessGroup,
          slotAccount: SharedSessionOwnerSlotStore.account(
            instanceFingerprint: namespaceFingerprint,
            ownerIdentifier: ownerIdentifier
          ),
          instanceFingerprint: namespaceFingerprint,
          ownerIdentifier: ownerIdentifier
        )
      } else {
        nil
      }
    let instanceFingerprint =
      ownerSlot?.instanceFingerprint ?? namespaceFingerprint

    func configuredTarget(
      service: String,
      accessGroup: String?
    ) -> AppContainerIdentityClearIntent.KeychainTarget {
      .init(
        kind: .configured,
        service: service,
        accessGroup: accessGroup,
        legacyAccessGroups: []
      )
    }

    func appLocalTarget(
      service: String
    ) -> AppContainerIdentityClearIntent.KeychainTarget {
      guard let appLocalAccessGroup else {
        return configuredTarget(
          service: service,
          accessGroup: service == keychainConfig.service
            ? sharedAccessGroup
            : nil
        )
      }
      return .init(
        kind: .applicationLocal,
        service: service,
        accessGroup: appLocalAccessGroup,
        legacyAccessGroups: legacyAccessGroups
      )
    }

    let stableIdentityService =
      ownerSlot?.localIdentityService
        ?? DependencyContainer.stableIdentityService(
          configuredService: keychainConfig.service,
          instanceFingerprint: instanceFingerprint,
          ownerIdentifier: ownerIdentifier
        )
    let configuredShared = configuredTarget(
      service: keychainConfig.service,
      accessGroup: sharedAccessGroup
    )
    let configuredAppLocal = appLocalTarget(service: keychainConfig.service)
    let stableIdentity: AppContainerIdentityClearIntent.KeychainTarget = if let ownerSlot {
      if let localIdentityAccessGroup =
        ownerSlot.localIdentityAccessGroup
      {
        .init(
          kind: .applicationLocal,
          service: ownerSlot.localIdentityService,
          accessGroup: localIdentityAccessGroup,
          legacyAccessGroups: legacyAccessGroups
        )
      } else {
        configuredTarget(
          service: ownerSlot.localIdentityService,
          accessGroup: nil
        )
      }
    } else {
      appLocalTarget(service: stableIdentityService)
    }
    let previousAppLocal: AppContainerIdentityClearIntent.KeychainTarget? = if let ownerIdentifier,
                                                                               !ownerIdentifier.isEmpty,
                                                                               ownerIdentifier != keychainConfig.service
    {
      appLocalTarget(service: ownerIdentifier)
    } else {
      nil
    }
    let clearJournal: AppContainerIdentityClearIntent.KeychainTarget? = if let ownerSlot {
      appLocalTarget(
        service: SharedSessionOwnerSlotClearRecovery.journalService(
          ownerIdentifier: ownerSlot.ownerIdentifier
        )
      )
    } else {
      nil
    }

    return try AppContainerIdentityClearIntent(
      instanceFingerprint: instanceFingerprint,
      ownerIdentifier: ownerIdentifier,
      configuredShared: configuredShared,
      configuredAppLocal: configuredAppLocal,
      stableIdentity: stableIdentity,
      previousAppLocal: previousAppLocal,
      clearJournal: clearJournal,
      ownerSlot: ownerSlot
    ).validated()
  }

  func recoverAppContainerIdentityClear(
    _ intent: AppContainerIdentityClearIntent,
    protecting currentDependencies: (any Dependencies)?
  ) throws {
    let intent = try intent.validated()
    guard let currentDependencies else {
      try appContainerIdentityClearRecovery.recover(intent)
      return
    }
    let currentConfiguration =
      currentDependencies.configurationManager
    let currentFingerprint = SharedSessionNamespace(
      frontendApiUrl: currentConfiguration.frontendApiUrl,
      publishableKey: currentConfiguration.publishableKey
    ).fingerprint
    guard currentFingerprint == intent.instanceFingerprint else {
      try appContainerIdentityClearRecovery.recover(intent)
      return
    }
    let currentIntent =
      try Self.makeAppContainerIdentityClearIntent(
        dependencies: currentDependencies,
        options: currentConfiguration.options,
        frontendApiUrl: currentConfiguration.frontendApiUrl,
        publishableKey: currentConfiguration.publishableKey
      )
    guard !intent.hasSameRecoveryTopology(as: currentIntent) else {
      try appContainerIdentityClearRecovery.recover(intent)
      return
    }
    try appContainerIdentityClearRecovery.recover([
      intent,
      currentIntent,
    ])
  }
}
