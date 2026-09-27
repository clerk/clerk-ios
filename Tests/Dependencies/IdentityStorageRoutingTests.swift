@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Security
import Testing

@MainActor
struct IdentityStorageRoutingTests {
  @Test(arguments: [false, true])
  func siblingMigrationCompletionMustNotSkipThisAppsLogin(atomicIdentity: Bool) throws {
    let database = AccessGroupKeychainDatabase()
    // App A completes migration without creating an identity. Its default group
    // is shared, so App B can see the marker through an unscoped query.
    let first = try app(database, service: "common-service", sharing: true, sharedGroupIsDefault: true)
    try #require(try first.dependencies.identityStore.load() == nil)
    let client = database.client(owner: "app.b", sharedGroupIsDefault: false)
    let legacy = SystemKeychain(service: "common-service", accessGroup: "app.b", secItemClient: client)
    try legacy.set("existing-login", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    if atomicIdentity {
      let fingerprint = first.dependencies.identityStore.instanceFingerprint
      let atomic = SystemKeychain(service: "app.b.clerk.identity.v2.\(fingerprint)", secItemClient: client)
      try atomic.set(JSONEncoder.clerkEncoder.encode(ClerkIdentitySnapshot(
        state: .present, deviceToken: "existing-login", client: .mock, serverDate: nil
      )), forKey: "clerkSharedSessionLocalIdentityV2")
    }

    let sibling = try app(database, service: "common-service", sharing: true, owner: "app.b")

    #expect(sibling.deviceToken == "existing-login")
    #expect(sibling.client?.id == (atomicIdentity ? Client.mock.id : nil))
    #expect(try first.dependencies.identityStore.load()?.identity.deviceToken == "existing-login")
    // Later launches must still honor B's clear despite the retained legacy token.
    try sibling.clearKeychainItems()
    #expect(try app(database, service: "common-service", sharing: true, owner: "app.b").deviceToken == nil)
  }

  @Test(arguments: [false, true])
  func siblingObservationMustNotSuppressThisAppsWatchClear(restart: Bool) throws {
    let database = AccessGroupKeychainDatabase()
    func app(_ owner: String, sharedDefault: Bool) throws -> Clerk {
      let clerk = Clerk()
      let client = database.client(owner: owner, sharedGroupIsDefault: sharedDefault)
      clerk.dependencies = try DependencyContainer(
        publishableKey: testPublishableKey,
        options: .init(telemetryEnabled: false, keychainConfig: .init(service: "common-service", accessGroup: "shared"),
                       sharedSessionSync: .enabled),
        runtimeScope: clerk.runtimeScope, migratesPersistentStateOverride: true,
        keychainFactory: { SystemKeychain(service: $0, accessGroup: $1, secItemClient: client) },
        ownerIdentifierProvider: { owner }
      )
      clerk.identityController.hydrate()
      return clerk
    }
    let first = try app("app.a", sharedDefault: true)
    try first.seedIdentity(deviceToken: "old-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    let sibling = try app("app.b", sharedDefault: false)
    try sibling.dependencies.appLocalKeychain.set("5", forKey: ClerkKeychainKey.watchSyncClearGeneration.rawValue)
    try first.dependencies.appLocalKeychain.set("1", forKey: ClerkKeychainKey.watchSyncClearGeneration.rawValue)
    let oldWatch = try WatchSyncState(of: sibling)
    try #require(oldWatch.clearGeneration == 5)
    try first.identityController.clearIdentity()
    let observer = restart ? try app("app.b", sharedDefault: false) : sibling
    if !restart { #expect(observer.identityController.reconcileWithStore()) }
    #expect(observer.deviceToken == nil)
    #expect(try WatchSyncState(of: observer).clearGeneration == 6)
    let coordinator = WatchConnectivityCoordinator(transport: RecordingWatchSyncTransport())
    coordinator.apply(WatchSyncPayload(state: oldWatch, environment: nil), from: .watch, to: observer)
    #expect(observer.deviceToken == nil)
    #expect(try observer.dependencies.identityStore.load()?.identity.deviceToken == nil)
    // Restarting either app must retain its observation without counting it twice.
    let firstGeneration = try WatchSyncState(of: first).clearGeneration
    #expect(try WatchSyncState(of: app("app.b", sharedDefault: false)).clearGeneration == 6)
    #expect(try WatchSyncState(of: app("app.a", sharedDefault: true)).clearGeneration == firstGeneration)
  }

  @Test(arguments: [false, true])
  func leavingSharingKeepsLocalUpdatesAndClearsOutOfTheGroup(sharedGroupIsDefault: Bool) throws {
    let database = AccessGroupKeychainDatabase()
    func app(_ owner: String, sharing: Bool) throws -> Clerk {
      let clerk = Clerk()
      let client = database.client(owner: owner, sharedGroupIsDefault: sharedGroupIsDefault)
      clerk.dependencies = try DependencyContainer(
        publishableKey: testPublishableKey,
        options: .init(telemetryEnabled: false, keychainConfig: .init(service: "common-service", accessGroup: "shared"),
                       sharedSessionSync: sharing ? .enabled : nil),
        runtimeScope: clerk.runtimeScope, migratesPersistentStateOverride: true,
        keychainFactory: { SystemKeychain(service: $0, accessGroup: $1, secItemClient: client) },
        ownerIdentifierProvider: { owner }
      )
      clerk.identityController.hydrate()
      return clerk
    }

    let first = try app("app.a", sharing: true)
    try first.seedIdentity(deviceToken: "shared-token", client: .mock)
    let sibling = try app("app.b", sharing: true)
    let sharedRecord = try #require(try sibling.dependencies.identityStore.load())
    let local = try app("app.a", sharing: false)
    #expect(local.deviceToken == "shared-token")
    try local.seedIdentity(deviceToken: "local-token", client: .mock)
    #expect(try sibling.dependencies.identityStore.load() == sharedRecord)
    try local.clearKeychainItems()
    #expect(try sibling.dependencies.identityStore.load() == sharedRecord)
    #expect(try app("app.a", sharing: false).deviceToken == nil)
    #expect(try app("app.b", sharing: true).deviceToken == "shared-token")
    #expect(try app("app.a", sharing: true).deviceToken == "shared-token")
  }

  @Test
  func unscopedQueriesReallyDoFindAndUpdateAnAccessibleSharedItem() throws {
    let database = AccessGroupKeychainDatabase()
    let client = database.client(owner: "app.a", sharedGroupIsDefault: false)
    let shared = SystemKeychain(service: "common", accessGroup: "shared", secItemClient: client)
    let unscoped = SystemKeychain(service: "common", secItemClient: client)
    let revision = UUID()
    #expect(try shared.compareAndSwap(Data("old".utf8), forKey: "identity", expectedRevision: nil, newRevision: revision))
    #expect(try unscoped.data(forKey: "identity") == Data("old".utf8))
    #expect(try unscoped.compareAndSwap(Data("new".utf8), forKey: "identity", expectedRevision: revision, newRevision: UUID()))
    #expect(try shared.data(forKey: "identity") == Data("new".utf8))
    try unscoped.deleteItem(forKey: "identity")
    #expect(try shared.data(forKey: "identity") == nil)
  }

  private func app(_ database: AccessGroupKeychainDatabase, service: String, sharing: Bool,
                   sharedGroupIsDefault: Bool = false, owner: String = "app.a") throws -> Clerk
  {
    let clerk = Clerk()
    let client = database.client(owner: owner, sharedGroupIsDefault: sharedGroupIsDefault)
    clerk.dependencies = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(telemetryEnabled: false,
                     keychainConfig: .init(service: service, accessGroup: sharing ? "shared" : nil),
                     sharedSessionSync: sharing ? .enabled : nil),
      runtimeScope: clerk.runtimeScope, migratesPersistentStateOverride: true,
      keychainFactory: { SystemKeychain(service: $0, accessGroup: $1, secItemClient: client) },
      ownerIdentifierProvider: { owner }
    )
    clerk.identityController.hydrate()
    return clerk
  }

  @Test(arguments: [false, true], [false, true])
  func migratedSourceMustNotRestoreClearedLogin(sameService: Bool, establishedSharedClear: Bool) throws {
    let database = AccessGroupKeychainDatabase()
    let original = try app(database, service: "app.a", sharing: false)
    try original.seedIdentity(deviceToken: "original-login", client: .mock)
    let sharedService = sameService ? "app.a" : "common-service"
    if establishedSharedClear {
      let keychain = SystemKeychain(service: sharedService, accessGroup: "shared",
                                    secItemClient: database.client(owner: "app.a", sharedGroupIsDefault: false))
      try ClerkIdentityStore(keychain: keychain, instanceFingerprint: original.dependencies.identityStore.instanceFingerprint).clear()
    }
    let sharing = try app(database, service: sharedService, sharing: true)
    try #require(sharing.deviceToken == (establishedSharedClear ? nil : "original-login"))
    try #require(sharing.client?.id == (establishedSharedClear ? nil : Client.mock.id))
    try sharing.clearKeychainItems()
    try #require(sharing.deviceToken == nil)
    let sharedRelaunch = try app(database, service: sharedService, sharing: true)
    try #require(sharedRelaunch.deviceToken == nil)
    let restoredConfiguration = try app(database, service: "app.a", sharing: false)
    #expect(restoredConfiguration.deviceToken == nil)
    #expect(restoredConfiguration.client == nil)
    try restoredConfiguration.seedIdentity(deviceToken: "new-local-login", client: .mock)
    #expect(try app(database, service: "app.a", sharing: false).deviceToken == "new-local-login")
  }

  @Test(arguments: [false, true])
  func migrationCleanupMustPreserveSiblingLegacyCredentials(sharedGroupIsDefault: Bool) throws {
    let database = AccessGroupKeychainDatabase()
    let firstClient = database.client(owner: "app.a", sharedGroupIsDefault: sharedGroupIsDefault)
    let shared = SystemKeychain(service: "common-service", accessGroup: "shared", secItemClient: firstClient)
    let tokenKey = ClerkKeychainKey.clerkDeviceToken.rawValue
    try shared.set("legacy-shared-login", forKey: tokenKey)
    for key in ClerkIdentityMigration.legacyIdentityKeys where key != .clerkDeviceToken {
      try shared.set("sibling-value", forKey: key.rawValue)
    }
    let siblingClient = database.client(owner: "app.b", sharedGroupIsDefault: false)
    let siblingShared = SystemKeychain(service: "common-service", accessGroup: "shared", secItemClient: siblingClient)
    try #require(try siblingShared.string(forKey: tokenKey) == "legacy-shared-login")
    let upgraded = try app(database, service: "common-service", sharing: true, sharedGroupIsDefault: sharedGroupIsDefault)
    try #require(upgraded.deviceToken == "legacy-shared-login")
    #expect(try siblingShared.string(forKey: tokenKey) == "legacy-shared-login")
    for key in ClerkIdentityMigration.legacyIdentityKeys where key != .clerkDeviceToken {
      #expect(try siblingShared.string(forKey: key.rawValue) == "sibling-value")
    }
  }

  @Test(arguments: [false, true])
  func failedMigrationCopyKeepsItsSourceRecoverable(returnToOriginalConfiguration: Bool) throws {
    let database = AccessGroupKeychainDatabase()
    let original = try app(database, service: "app.a", sharing: false)
    try original.seedIdentity(deviceToken: "original-login", client: .mock)
    database.rejectIdentityCreation = true
    let failed = try app(database, service: "common-service", sharing: true)
    #expect(failed.deviceToken == nil)
    #expect(try failed.dependencies.identityStore.load() == nil)

    database.rejectIdentityCreation = false
    let recovered = try app(database, service: returnToOriginalConfiguration ? "app.a" : "common-service",
                            sharing: !returnToOriginalConfiguration)
    #expect(recovered.deviceToken == "original-login")
    #expect(recovered.client?.id == Client.mock.id)
  }

  @Test
  func interruptedSourceRetirementIsRecoveredFromTheCommittedDestination() throws {
    let database = AccessGroupKeychainDatabase()
    let original = try app(database, service: "app.a", sharing: false)
    try original.seedIdentity(deviceToken: "original-login", client: .mock)
    database.rejectRetirementCompletion = true
    let interrupted = try app(database, service: "common-service", sharing: true)
    #expect(interrupted.deviceToken == nil)
    #expect(try interrupted.dependencies.identityStore.load()?.identity.deviceToken == "original-login")
    // A peer can clear the committed shared record while this app has not finished
    // recording completion. Restart directly in the original configuration.
    try interrupted.dependencies.identityStore.clear()
    database.rejectRetirementCompletion = false
    let restored = try app(database, service: "app.a", sharing: false)
    #expect(restored.deviceToken == nil)
    #expect(restored.client == nil)
  }

  @Test(arguments: [false, true])
  func retainedLegacySourceCannotRestoreAClearedMigratedLogin(interruptedAtomicCleanup: Bool) throws {
    let database = AccessGroupKeychainDatabase()
    let client = database.client(owner: "app.a", sharedGroupIsDefault: false)
    let original = SystemKeychain(service: "app.a", accessGroup: "app.a", secItemClient: client)
    let key = ClerkKeychainKey.clerkDeviceToken.rawValue
    try original.set("legacy-login", forKey: key)
    if interruptedAtomicCleanup {
      let config = ConfigurationManager()
      try config.configure(publishableKey: testPublishableKey, options: .init())
      let fingerprint = SharedSessionNamespace(frontendApiUrl: config.frontendApiUrl, publishableKey: testPublishableKey).fingerprint
      let atomic = SystemKeychain(service: "app.a.clerk.identity.v2.\(fingerprint)", secItemClient: client)
      try atomic.set(JSONEncoder.clerkEncoder.encode(ClerkIdentitySnapshot(
        state: .present, deviceToken: "legacy-login", client: .mock, serverDate: nil
      )), forKey: "clerkSharedSessionLocalIdentityV2")
      database.rejectAtomicDeletion = true
    }
    let sharing = try app(database, service: "common-service", sharing: true)
    #expect(sharing.deviceToken == "legacy-login")
    #expect(try original.string(forKey: key) == "legacy-login")
    try sharing.clearKeychainItems()
    database.rejectAtomicDeletion = false
    #expect(try app(database, service: "app.a", sharing: false).deviceToken == nil)
  }

  @Test(arguments: [false, true], [false, true])
  func retainedAtomicSourceCannotUndoAPublicClearAfterChangingService(cleanupFails: Bool, adoptedSync: Bool) throws {
    let database = AccessGroupKeychainDatabase()
    let atomic = try seedAtomicIdentity(database)
    if adoptedSync {
      try atomic.set("2", forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue)
    }
    database.rejectAtomicDeletion = cleanupFails
    let original = try app(database, service: "app.a", sharing: false)
    try #require(original.deviceToken == "old-login")
    try #require(try atomic.hasItem(forKey: "clerkSharedSessionLocalIdentityV2") == cleanupFails)

    try original.clearKeychainItems()
    try #require(try original.dependencies.identityStore.load()?.identity == .signedOut)
    database.rejectAtomicDeletion = false
    let sharing = try app(database, service: "common-service", sharing: true)

    #expect(sharing.deviceToken == nil)
    #expect(sharing.client?.id == nil)
    #expect(try !atomic.hasItem(forKey: "clerkSharedSessionLocalIdentityV2"))
    #expect(try app(database, service: "common-service", sharing: true).deviceToken == nil)
  }

  @Test(arguments: [false, true])
  func atomicRetirementAcrossServicesRequiresACommittedDestination(copyFails: Bool) throws {
    let database = AccessGroupKeychainDatabase()
    let atomic = try seedAtomicIdentity(database)
    try atomic.set("2", forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue)
    database.rejectAtomicDeletion = true
    database.rejectIdentityCreation = copyFails
    database.rejectRetirementCompletion = !copyFails
    let interrupted = try app(database, service: "app.a", sharing: false)
    #expect(interrupted.deviceToken == nil)
    let store = interrupted.dependencies.identityStore
    #expect(try store.load()?.identity.deviceToken == (copyFails ? nil : "old-login"))
    if !copyFails {
      // Model a clear committed before the migration completion write recovered.
      try store.clear()
    }
    database.rejectIdentityCreation = false
    database.rejectRetirementCompletion = false
    database.rejectAtomicDeletion = false

    let sharing = try app(database, service: "common-service", sharing: true)

    #expect(sharing.deviceToken == (copyFails ? "old-login" : nil))
    #expect(sharing.client?.id == (copyFails ? Client.mock.id : nil))
    #expect(try !atomic.hasItem(forKey: "clerkSharedSessionLocalIdentityV2"))
  }

  private func seedAtomicIdentity(_ database: AccessGroupKeychainDatabase) throws -> SystemKeychain {
    let config = ConfigurationManager()
    try config.configure(publishableKey: testPublishableKey, options: .init())
    let fingerprint = SharedSessionNamespace(frontendApiUrl: config.frontendApiUrl, publishableKey: testPublishableKey).fingerprint
    let atomic = SystemKeychain(service: "app.a.clerk.identity.v2.\(fingerprint)",
                                secItemClient: database.client(owner: "app.a", sharedGroupIsDefault: false))
    try atomic.set(JSONEncoder.clerkEncoder.encode(ClerkIdentitySnapshot(
      state: .present, deviceToken: "old-login", client: .mock, serverDate: nil
    )), forKey: "clerkSharedSessionLocalIdentityV2")
    return atomic
  }
}

/// Models Apple's access-group matching while exercising the actual SystemKeychain
/// query builder. A nil group searches every accessible group; adds use the first one.
private final class AccessGroupKeychainDatabase: @unchecked Sendable {
  private let lock = NSLock()
  private var items: [[String: Any]] = []
  var rejectIdentityCreation = false
  var rejectRetirementCompletion = false
  var rejectAtomicDeletion = false

  func client(owner: String, sharedGroupIsDefault: Bool) -> SystemKeychain.SecItemClient {
    let groups = sharedGroupIsDefault ? ["shared", owner] : [owner, "shared"]
    return .init(
      add: { query, _ in
        self.lock.withLock {
          var item = query as! [String: Any]
          if self.rejectIdentityCreation, item[kSecAttrGeneric as String] != nil { return errSecInteractionNotAllowed }
          if self.rejectsRetirementWrite(query: item, attributes: item) { return errSecInteractionNotAllowed }
          item[kSecAttrAccessGroup as String] = item[kSecAttrAccessGroup as String] ?? groups[0]
          guard groups.contains(item[kSecAttrAccessGroup as String] as! String) else { return errSecMissingEntitlement }
          let identityKeys = [kSecClass, kSecAttrService, kSecAttrAccount, kSecAttrAccessGroup].map { $0 as String }
          let identity = item.filter { identityKeys.contains($0.key) }
          guard !self.items.contains(where: { self.matches($0, query: identity, groups: groups) }) else { return errSecDuplicateItem }
          self.items.append(item)
          return errSecSuccess
        }
      },
      update: { query, attributes in
        self.lock.withLock {
          if self.rejectsRetirementWrite(query: query as! [String: Any], attributes: attributes as! [String: Any]) {
            return errSecInteractionNotAllowed
          }
          let indices = self.items.indices.filter { self.matches(self.items[$0], query: query as! [String: Any], groups: groups) }
          guard !indices.isEmpty else { return errSecItemNotFound }
          for index in indices {
            self.items[index].merge(attributes as! [String: Any]) { _, new in new }
          }
          return errSecSuccess
        }
      },
      copyMatching: { query, result in
        self.lock.withLock {
          let query = query as! [String: Any]
          let matches = self.items.filter { self.matches($0, query: query, groups: groups) }
          guard let first = matches.first else { return errSecItemNotFound }
          if query[kSecMatchLimit as String] as? String == kSecMatchLimitAll as String {
            result?.pointee = matches as CFArray
          } else if query[kSecReturnData as String] as? Bool == true {
            result?.pointee = first[kSecValueData as String] as CFTypeRef?
          }
          return errSecSuccess
        }
      },
      delete: { query in
        self.lock.withLock {
          if self.rejectAtomicDeletion,
             (query as! [String: Any])[kSecAttrAccount as String] as? String == "clerkSharedSessionLocalIdentityV2"
          { return errSecInteractionNotAllowed }
          let count = self.items.count
          self.items.removeAll { self.matches($0, query: query as! [String: Any], groups: groups) }
          return self.items.count == count ? errSecItemNotFound : errSecSuccess
        }
      }
    )
  }

  private func rejectsRetirementWrite(query: [String: Any], attributes: [String: Any]) -> Bool {
    guard rejectRetirementCompletion,
          let key = query[kSecAttrAccount as String] as? String, key.contains(".retiredSource."),
          let data = attributes[kSecValueData as String] as? Data,
          let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
    return value["completed"] as? Bool == true
  }

  private func matches(_ item: [String: Any], query: [String: Any], groups: [String]) -> Bool {
    guard let group = item[kSecAttrAccessGroup as String] as? String, groups.contains(group) else { return false }
    return [kSecClass, kSecAttrService, kSecAttrAccount, kSecAttrAccessGroup, kSecAttrGeneric].allSatisfy {
      let key = $0 as String
      guard let value = query[key] as? NSObject else { return true }
      return value.isEqual(item[key])
    }
  }
}
