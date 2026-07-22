@testable import ClerkKit
import Foundation
import Testing

struct SharedSessionSyncAdoptionTests {
  @Test
  func destructiveConfigurationMarksAdoptedWithoutMigratingCredentials() throws {
    let destination = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    try persistLegacyIdentity(
      token: "other-instance-token",
      client: makeClient(id: "other-instance-client"),
      in: legacyShared
    )

    try makeAdoption(
      destination: destination,
      privateKeychain: InMemoryKeychain(),
      previousBundle: nil,
      legacyShared: legacyShared
    ).markAdoptedWithoutMigratingCredentials()

    #expect(try SharedSessionSyncAdoption.isAdopted(in: destination))
    #expect(try SharedSessionLocalIdentityStore(keychain: destination).load() == nil)
  }

  @Test
  func configuredAppLocalIdentityTakesPrecedenceAndMigratesEnvironment() throws {
    let destination = InMemoryKeychain()
    let privateKeychain = InMemoryKeychain()
    let configuredAppLocal = InMemoryKeychain()
    let previousBundle = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    try persistLegacyIdentity(
      token: "configured-token",
      client: makeClient(id: "configured-client"),
      in: configuredAppLocal
    )
    try persistLegacyIdentity(
      token: "bundle-token",
      client: makeClient(id: "bundle-client"),
      in: previousBundle
    )
    let environmentData = try JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock)
    try configuredAppLocal.set(environmentData, forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    try makeAdoption(
      destination: destination,
      privateKeychain: privateKeychain,
      configuredAppLocal: configuredAppLocal,
      previousBundle: previousBundle,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    let store = SharedSessionLocalIdentityStore(keychain: destination)
    let identity = try #require(try store.load())
    #expect(identity.state == .cleared)
    #expect(identity.deviceToken == "configured-token")
    #expect(identity.client == nil)
    #expect(try store.loadRecord()?.requiresLegacyAdoptionPublication == true)
    #expect(try privateKeychain.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == environmentData)
  }

  @Test
  func privateAppStateMigratesOnlyFromAppAttributedStorage() throws {
    let destination = InMemoryKeychain()
    let privateKeychain = InMemoryKeychain()
    let configuredAppLocal = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    let flow = PendingMagicLinkFlow(
      kind: .signIn,
      flowId: "flow",
      codeVerifier: "verifier",
      createdAt: Date(),
      expiresAt: Date().addingTimeInterval(600)
    )
    let flowData = try JSONEncoder.clerkEncoder.encode(flow)
    try configuredAppLocal.set(flowData, forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue)
    try configuredAppLocal.set("app-attest", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    try legacyShared.set("shared-attest", forKey: ClerkKeychainKey.attestKeyId.rawValue)

    try makeAdoption(
      destination: destination,
      privateKeychain: privateKeychain,
      configuredAppLocal: configuredAppLocal,
      previousBundle: nil,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    #expect(try privateKeychain.data(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == flowData)
    #expect(try privateKeychain.string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == "app-attest")
  }

  @Test
  func ambiguousSharedPrivateAppStateIsNotMigrated() throws {
    let privateKeychain = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    try legacyShared.set("shared-attest", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    try legacyShared.set(Data("shared-flow".utf8), forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue)

    try makeAdoption(
      destination: InMemoryKeychain(),
      privateKeychain: privateKeychain,
      previousBundle: nil,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    #expect(try privateKeychain.data(forKey: ClerkKeychainKey.attestKeyId.rawValue) == nil)
    #expect(try privateKeychain.data(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == nil)
  }

  @Test
  func previousBundleTokenTakesPrecedenceOverLegacySharedToken() throws {
    let destination = InMemoryKeychain()
    let privateKeychain = InMemoryKeychain()
    let previousBundle = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    try persistLegacyIdentity(
      token: "bundle-token",
      client: makeClient(id: "bundle-client"),
      in: previousBundle
    )
    try persistLegacyIdentity(
      token: "shared-token",
      client: makeClient(id: "shared-client"),
      in: legacyShared
    )

    try makeAdoption(
      destination: destination,
      privateKeychain: privateKeychain,
      previousBundle: previousBundle,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    let store = SharedSessionLocalIdentityStore(keychain: destination)
    let identity = try #require(try store.load())
    #expect(identity.state == .cleared)
    #expect(identity.deviceToken == "bundle-token")
    #expect(identity.client == nil)
    #expect(try store.loadRecord()?.requiresLegacyAdoptionPublication == true)
  }

  @Test
  func incoherentSourceIsSkippedWithoutMixingIdentityFields() throws {
    let destination = InMemoryKeychain()
    let previousBundle = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    try previousBundle.set(
      JSONEncoder.clerkEncoder.encode(makeClient(id: "orphan-client")),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    try persistLegacyIdentity(
      token: "shared-token",
      client: makeClient(id: "shared-client"),
      in: legacyShared
    )

    try makeAdoption(
      destination: destination,
      privateKeychain: InMemoryKeychain(),
      previousBundle: previousBundle,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    let identity = try #require(try SharedSessionLocalIdentityStore(keychain: destination).load())
    #expect(identity.state == .cleared)
    #expect(identity.deviceToken == "shared-token")
    #expect(identity.client == nil)
  }

  @Test
  func malformedTokenFallsThroughToValidLaterSource() throws {
    let destination = InMemoryKeychain()
    let previousBundle = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    try previousBundle.set(
      Data([0xFF]),
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    try persistLegacyIdentity(
      token: "shared-token",
      client: makeClient(id: "shared-client"),
      in: legacyShared
    )

    try makeAdoption(
      destination: destination,
      privateKeychain: InMemoryKeychain(),
      previousBundle: previousBundle,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    let identity = try #require(try SharedSessionLocalIdentityStore(keychain: destination).load())
    #expect(identity.state == .cleared)
    #expect(identity.deviceToken == "shared-token")
    #expect(identity.client == nil)
  }

  @Test
  func malformedLegacyClientDoesNotBlockTokenOnlyAdoption() throws {
    let destination = InMemoryKeychain()
    let previousBundle = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    try previousBundle.set("bundle-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try previousBundle.set(
      Data("not-a-client".utf8),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    try persistLegacyIdentity(
      token: "shared-token",
      client: makeClient(id: "shared-client"),
      in: legacyShared
    )

    try makeAdoption(
      destination: destination,
      privateKeychain: InMemoryKeychain(),
      previousBundle: previousBundle,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    let identity = try #require(try SharedSessionLocalIdentityStore(keychain: destination).load())
    #expect(identity.state == .cleared)
    #expect(identity.deviceToken == "bundle-token")
    #expect(identity.client == nil)
  }

  @Test
  func malformedOrNonfiniteLegacyDateDoesNotBlockTokenOnlyAdoption() throws {
    for invalidDate in ["not-a-date", "nan", "infinity"] {
      let destination = InMemoryKeychain()
      let previousBundle = InMemoryKeychain()
      let legacyShared = InMemoryKeychain()
      try previousBundle.set("bundle-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
      try previousBundle.set(
        invalidDate,
        forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
      )
      try persistLegacyIdentity(
        token: "shared-token",
        client: makeClient(id: "shared-client"),
        in: legacyShared
      )

      try makeAdoption(
        destination: destination,
        privateKeychain: InMemoryKeychain(),
        previousBundle: previousBundle,
        legacyShared: legacyShared
      ).migrateIfNeeded()

      let identity = try #require(try SharedSessionLocalIdentityStore(keychain: destination).load())
      #expect(identity.state == .cleared)
      #expect(identity.deviceToken == "bundle-token")
      #expect(identity.client == nil)
    }
  }

  @Test
  func dateOnlySourceFallsThroughToValidLaterSource() throws {
    let destination = InMemoryKeychain()
    let previousBundle = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    try previousBundle.set(
      "100",
      forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
    )
    try persistLegacyIdentity(
      token: "shared-token",
      client: makeClient(id: "shared-client"),
      in: legacyShared
    )

    try makeAdoption(
      destination: destination,
      privateKeychain: InMemoryKeychain(),
      previousBundle: previousBundle,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    let identity = try #require(try SharedSessionLocalIdentityStore(keychain: destination).load())
    #expect(identity.state == .cleared)
    #expect(identity.deviceToken == "shared-token")
    #expect(identity.client == nil)
  }

  @Test
  func keychainReadFailureFailsClosedInsteadOfFallingThrough() throws {
    let legacyShared = InMemoryKeychain()
    try persistLegacyIdentity(
      token: "shared-token",
      client: makeClient(id: "shared-client"),
      in: legacyShared
    )

    #expect(throws: FailingReadKeychain.Failure.self) {
      try makeAdoption(
        destination: InMemoryKeychain(),
        privateKeychain: InMemoryKeychain(),
        previousBundle: FailingReadKeychain(),
        legacyShared: legacyShared
      ).migrateIfNeeded()
    }
  }

  @Test
  func existingStableIdentityIsNeverReplacedDuringAdoption() throws {
    let destination = InMemoryKeychain()
    let stableStore = SharedSessionLocalIdentityStore(keychain: destination)
    try stableStore.save(
      SharedSessionLocalIdentity(
        state: .present,
        deviceToken: "stable-token",
        client: makeClient(id: "stable-client"),
        serverDate: nil
      )
    )
    let legacyShared = InMemoryKeychain()
    try persistLegacyIdentity(
      token: "shared-token",
      client: makeClient(id: "shared-client"),
      in: legacyShared
    )

    try makeAdoption(
      destination: destination,
      privateKeychain: InMemoryKeychain(),
      previousBundle: nil,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    #expect(try stableStore.load()?.deviceToken == "stable-token")
    #expect(try stableStore.load()?.client?.id == "stable-client")
  }

  @Test
  func environmentMovesAppLocallyWhileLegacySharedValuesRemainInert() throws {
    let destination = InMemoryKeychain()
    let privateKeychain = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    let environmentData = try JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock)
    try legacyShared.set(environmentData, forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    try persistLegacyIdentity(
      token: "token",
      client: makeClient(id: "client"),
      in: legacyShared
    )

    try makeAdoption(
      destination: destination,
      privateKeychain: privateKeychain,
      previousBundle: nil,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    #expect(try privateKeychain.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == environmentData)
    #expect(try legacyShared.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == environmentData)
    #expect(try legacyShared.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "token")
  }

  @Test
  func markerIsWrittenOnlyAfterMigrationCompletes() throws {
    let destination = SelectivelyFailingKeychain(failingKey: SharedSessionLocalIdentityStore.storageKey)
    let legacyShared = InMemoryKeychain()
    try persistLegacyIdentity(
      token: "token",
      client: makeClient(id: "client"),
      in: legacyShared
    )

    #expect(throws: SelectivelyFailingKeychain.Failure.self) {
      try makeAdoption(
        destination: destination,
        privateKeychain: InMemoryKeychain(),
        previousBundle: nil,
        legacyShared: legacyShared
      ).migrateIfNeeded()
    }

    #expect(
      try destination.string(forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue) == nil
    )
  }

  @Test
  func tokenOnlyLegacyIdentityAdoptsAsCoherentClearedState() throws {
    let destination = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    try legacyShared.set("token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    try makeAdoption(
      destination: destination,
      privateKeychain: InMemoryKeychain(),
      previousBundle: nil,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    let store = SharedSessionLocalIdentityStore(keychain: destination)
    let identity = try #require(try store.load())
    #expect(identity.state == .cleared)
    #expect(identity.deviceToken == "token")
    #expect(identity.client == nil)
    #expect(try store.loadRecord()?.requiresLegacyAdoptionPublication == false)
  }

  @Test
  func adoptedStableIdentityDoesNotResurrectChangedLegacyStateWhenSyncIsDisabled() throws {
    let destination = InMemoryKeychain()
    let legacyShared = InMemoryKeychain()
    try persistLegacyIdentity(
      token: "adopted-token",
      client: makeClient(id: "adopted-client"),
      in: legacyShared
    )
    let adoption = makeAdoption(
      destination: destination,
      privateKeychain: InMemoryKeychain(),
      previousBundle: nil,
      legacyShared: legacyShared
    )
    try adoption.migrateIfNeeded()

    try persistLegacyIdentity(
      token: "later-legacy-token",
      client: makeClient(id: "later-legacy-client"),
      in: legacyShared
    )

    #expect(try SharedSessionSyncAdoption.isAdopted(in: destination))
    let stable = try #require(try SharedSessionLocalIdentityStore(keychain: destination).load())
    #expect(stable.state == .cleared)
    #expect(stable.deviceToken == "adopted-token")
    #expect(stable.client == nil)
  }

  @Test
  func staggeredSiblingAdoptionsCanReadTheSameUntouchedLegacyIdentity() throws {
    let legacyShared = InMemoryKeychain()
    try persistLegacyIdentity(
      token: "legacy-token",
      client: makeClient(id: "legacy-client"),
      in: legacyShared
    )
    let firstDestination = InMemoryKeychain()
    let secondDestination = InMemoryKeychain()

    try makeAdoption(
      destination: firstDestination,
      privateKeychain: InMemoryKeychain(),
      previousBundle: nil,
      legacyShared: legacyShared
    ).migrateIfNeeded()
    try makeAdoption(
      destination: secondDestination,
      privateKeychain: InMemoryKeychain(),
      previousBundle: nil,
      legacyShared: legacyShared
    ).migrateIfNeeded()

    let first = try #require(try SharedSessionLocalIdentityStore(keychain: firstDestination).load())
    let second = try #require(try SharedSessionLocalIdentityStore(keychain: secondDestination).load())
    #expect(first == second)
    #expect(try legacyShared.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "legacy-token")
  }

  private func makeAdoption(
    destination: any KeychainStorage,
    privateKeychain: any KeychainStorage,
    configuredAppLocal: (any KeychainStorage)? = nil,
    previousBundle: (any KeychainStorage)?,
    legacyShared: any KeychainStorage
  ) -> SharedSessionSyncAdoption {
    SharedSessionSyncAdoption(
      destinationIdentity: destination,
      destinationPrivate: privateKeychain,
      configuredAppLocalIdentity: configuredAppLocal,
      previousAppLocalIdentity: previousBundle,
      legacyShared: legacyShared
    )
  }

  private func persistLegacyIdentity(
    token: String,
    client: Client,
    in keychain: any KeychainStorage
  ) throws {
    try keychain.set(token, forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(client),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
  }

  private func makeClient(id: String) -> Client {
    var client = Client.mockSignedOut
    client.id = id
    return client
  }
}

private final class SelectivelyFailingKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case set
  }

  private let storage = InMemoryKeychain()
  private let failingKey: String

  init(failingKey: String) {
    self.failingKey = failingKey
  }

  func set(_ data: Data, forKey key: String) throws {
    guard key != failingKey else { throw Failure.set }
    try storage.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try storage.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try storage.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try storage.hasItem(forKey: key)
  }
}

private final class FailingReadKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case read
  }

  func set(_: Data, forKey _: String) throws {}

  func data(forKey _: String) throws -> Data? {
    throw Failure.read
  }

  func deleteItem(forKey _: String) throws {}

  func hasItem(forKey _: String) throws -> Bool {
    throw Failure.read
  }
}
