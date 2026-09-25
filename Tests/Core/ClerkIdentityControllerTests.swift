//
//  ClerkIdentityControllerTests.swift
//  Clerk
//

@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkIdentityControllerTests {
  @Test
  func responsePersistsTokenClientAndDateAsOneRecordBeforeUpdatingMemory() async throws {
    let (clerk, _) = makeClerk()
    var persistedWhenClientChanged: ClerkIdentitySnapshot?
    let observer = ClientChangeObserver {
      persistedWhenClientChanged = try? clerk.dependencies.identityStore.load()?.identity
    }
    clerk.internalStateChanges.addObserver(observer)

    try await clerk.identityController.applyNetworkResponse(
      context(.client(makeClient(id: "client")), token: .set("token"), requestToken: nil, clerk: clerk, date: 100)
    )

    let persisted = try #require(try clerk.dependencies.identityStore.load()?.identity)
    #expect(persisted.deviceToken == "token")
    #expect(persisted.client?.id == "client")
    #expect(persisted.serverDate == date(100))
    #expect(persistedWhenClientChanged?.client?.id == "client")
    #expect(clerk.deviceToken == "token")
    #expect(clerk.client?.id == "client")
    #expect(clerk.lastClientServerFetchDate == date(100))
  }

  @Test
  func hydrateLoadsThePersistedIdentityWithoutReplacingAFreshClient() throws {
    let (clerk, _) = makeClerk()
    try clerk.dependencies.identityStore.save(identity(token: "token", client: makeClient(id: "persisted"), date: 100))

    clerk.identityController.hydrate()
    #expect(clerk.deviceToken == "token")
    #expect(clerk.client?.id == "persisted")
    #expect(clerk.lastClientServerFetchDate == date(100))

    let (freshClerk, _) = makeClerk(keychain: clerk.dependencies.keychain as? InMemoryKeychain)
    freshClerk.client = makeClient(id: "fresh")
    freshClerk.identityController.hydrate()
    #expect(freshClerk.deviceToken == "token")
    #expect(freshClerk.client?.id == "fresh")
  }

  @Test
  func canonicalClientWithoutATokenIsRejected() async throws {
    let (clerk, keychain) = makeClerk()

    await #expect(throws: ClientSyncResponseError.missingDeviceTokenForCanonicalClient) {
      try await clerk.identityController.applyNetworkResponse(
        context(.client(.mock), token: .absent, requestToken: nil, clerk: clerk)
      )
    }

    #expect(clerk.client == nil)
    #expect(keychain.isEmpty)
  }

  @Test
  func tokenRotationFencesResponsesForTheOldToken() async throws {
    let (clerk, _) = makeClerk()
    try clerk.seedIdentity(deviceToken: "old-token")
    let oldGeneration = clerk.clientResponseGeneration

    try await clerk.identityController.applyNetworkResponse(
      context(.client(makeClient(id: "new")), token: .set("new-token"), requestToken: "old-token", clerk: clerk, date: 100)
    )
    #expect(clerk.deviceToken == "new-token")
    #expect(clerk.clientResponseGeneration != oldGeneration)

    try await clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
      update: .client(makeClient(id: "old")),
      deviceTokenUpdate: .absent,
      requestDeviceToken: "old-token",
      serverDate: date(200),
      isCanonicalClientRequest: true,
      clientResponseGeneration: oldGeneration,
      responseSequence: 2
    ))

    #expect(clerk.client?.id == "new")
    #expect(try clerk.dependencies.identityStore.load()?.identity.deviceToken == "new-token")
  }

  @Test
  func explicitClearDeletesTheRecord() async throws {
    let (clerk, _) = makeClerk()
    try clerk.seedIdentity(deviceToken: "token", client: makeClient(id: "client"), serverDate: date(100))

    try await clerk.identityController.applyNetworkResponse(
      context(.explicitClear, token: .clear, requestToken: "token", clerk: clerk, date: 200)
    )

    #expect(clerk.deviceToken == nil)
    #expect(clerk.client == nil)
    #expect(try clerk.dependencies.identityStore.load() == nil)
  }

  @Test
  func failedWriteOfANewTokenLeavesMemoryUnchanged() async throws {
    let (clerk, _) = makeClerk(identityKeychain: SetFailingKeychain())

    await #expect(throws: SetFailingKeychain.Failure.set) {
      try await clerk.identityController.applyNetworkResponse(
        context(.client(makeClient(id: "client")), token: .set("token"), requestToken: nil, clerk: clerk)
      )
    }

    #expect(clerk.deviceToken == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func failedWriteOfAClientForTheSameTokenStillUpdatesMemory() async throws {
    let keychain = FailingAfterFirstWriteKeychain()
    let (clerk, _) = makeClerk(identityKeychain: keychain)
    try clerk.seedIdentity(deviceToken: "token")

    try await clerk.identityController.applyNetworkResponse(
      context(.client(makeClient(id: "client")), token: .absent, requestToken: "token", clerk: clerk, date: 100)
    )

    #expect(clerk.deviceToken == "token")
    #expect(clerk.client?.id == "client")
  }

  @Test
  func undatedResponsePreservesServerDateWatermark() async throws {
    let (clerk, _) = makeClerk()
    try clerk.seedIdentity(deviceToken: "token", client: makeClient(id: "current"), serverDate: date(200))

    try await clerk.identityController.applyNetworkResponse(
      context(.client(makeClient(id: "undated")), token: .set("token"), requestToken: "token", clerk: clerk)
    )

    #expect(clerk.client?.id == "undated")
    #expect(clerk.lastClientServerFetchDate == date(200))
  }

  @Test
  func updateDeviceTokenPersistsTokenWithoutClient() async throws {
    let (clerk, _) = makeClerk()
    try clerk.seedIdentity(deviceToken: "old-token", client: makeClient(id: "client"), serverDate: date(100))

    let result = try await clerk.identityController.updateDeviceToken(to: "new-token")

    #expect(result == .applied)
    #expect(clerk.deviceToken == "new-token")
    #expect(clerk.client == nil)
    let persisted = try #require(try clerk.dependencies.identityStore.load()?.identity)
    #expect(persisted.deviceToken == "new-token")
    #expect(persisted.client == nil)
    #expect(try await clerk.identityController.updateDeviceToken(to: "new-token") == .unchanged)
  }

  @Test
  func externalTransitionPersistsBeforeRunningCompletion() throws {
    let (clerk, _) = makeClerk()
    var persistedInCompletion: ClerkIdentitySnapshot?

    try clerk.identityController.applyExternalTransition {
      ClerkIdentityController.ExternalTransition(
        identity: identity(token: "token", client: makeClient(id: "client"), date: 100),
        didApply: { persistedInCompletion = try? clerk.dependencies.identityStore.load()?.identity }
      )
    }

    #expect(persistedInCompletion?.client?.id == "client")
    #expect(clerk.client?.id == "client")
    #expect(clerk.deviceToken == "token")
  }

  @Test
  func reloadAppliesAnotherProcessesWriteAndTheCachedEnvironment() async throws {
    let (clerk, keychain) = makeClerk()
    try clerk.seedIdentity(deviceToken: "token", client: makeClient(id: "current"), serverDate: date(100))
    try clerk.dependencies.identityStore.save(identity(token: "token", client: makeClient(id: "written"), date: 200))
    try keychain.set(JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    #expect(await clerk.reloadFromSharedStorage())
    #expect(clerk.client?.id == "written")
    #expect(clerk.lastClientServerFetchDate == date(200))
    #expect(clerk.environment == .mock)
    #expect(await !clerk.reloadFromSharedStorage())
  }

  @Test
  func clearIdentityDeletesTheRecordAndSignsOut() throws {
    let (clerk, _) = makeClerk()
    try clerk.seedIdentity(deviceToken: "token", client: makeClient(id: "client"), serverDate: date(100))
    let generation = clerk.clientResponseGeneration

    try clerk.identityController.clearIdentity()

    #expect(clerk.deviceToken == nil)
    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == nil)
    #expect(clerk.clientResponseGeneration != generation)
    #expect(try clerk.dependencies.identityStore.load() == nil)
  }

  @Test
  func rejectedSignInResponseStillCompletesWhenItsSessionIsAlreadyCurrent() async throws {
    let (clerk, _) = makeClerk()
    try clerk.seedIdentity(deviceToken: "token", client: .mock, serverDate: date(200))
    let stream = clerk.auth.events
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = Client.mock.currentSession?.id

    try await clerk.identityController.applyNetworkResponse(ClientSyncResponseContext(
      update: .client(.mock),
      deviceTokenUpdate: .absent,
      requestDeviceToken: "token",
      serverDate: date(200),
      isCanonicalClientRequest: false,
      clientResponseGeneration: ClientResponseGeneration.initial.next().next(),
      responseSequence: 1,
      completedAuthFlow: .signIn(signIn)
    ))
    clerk.auth.send(.accountDeleted)

    var sawCompletion = false
    for await event in stream {
      if case .signInCompleted = event { sawCompletion = true }
      if case .accountDeleted = event { break }
    }
    #expect(sawCompletion)
  }

  // MARK: - Helpers

  private func makeClerk(
    keychain: InMemoryKeychain? = nil,
    identityKeychain: (any KeychainStorage)? = nil
  ) -> (Clerk, InMemoryKeychain) {
    let clerk = Clerk()
    let keychain = keychain ?? InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      identityKeychain: identityKeychain
    )
    return (clerk, keychain)
  }

  private func context(
    _ update: ClientResponseUpdate,
    token: ClerkDeviceTokenResponseUpdate,
    requestToken: String?,
    clerk: Clerk,
    date seconds: TimeInterval? = nil
  ) -> ClientSyncResponseContext {
    ClientSyncResponseContext(
      update: update,
      deviceTokenUpdate: token,
      requestDeviceToken: requestToken,
      serverDate: seconds.map(date),
      isCanonicalClientRequest: true,
      clientResponseGeneration: clerk.clientResponseGeneration,
      responseSequence: 1
    )
  }

  private func identity(token: String, client: Client?, date seconds: TimeInterval) -> ClerkIdentitySnapshot {
    ClerkIdentitySnapshot(
      state: client == nil ? .cleared : .present,
      deviceToken: token,
      client: client,
      serverDate: date(seconds)
    )
  }

  private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
  }

  private func makeClient(id: String) -> Client {
    var client = Client.mock
    client.id = id
    return client
  }
}

@MainActor
private final class ClientChangeObserver: ClerkInternalStateChangeObserver {
  private let onClientChange: () -> Void

  init(onClientChange: @escaping () -> Void) {
    self.onClientChange = onClientChange
  }

  func handle(_ change: ClerkInternalStateChange, from _: Clerk) throws {
    if case .clientDidChange = change {
      onClientChange()
    }
  }
}

private final class FailingAfterFirstWriteKeychain: @unchecked Sendable, KeychainStorage {
  private let backing = InMemoryKeychain()
  private let lock = NSLock()
  private var writes = 0

  func set(_ data: Data, forKey key: String) throws {
    let shouldFail = lock.withLock {
      writes += 1
      return writes > 1
    }
    if shouldFail { throw SetFailingKeychain.Failure.set }
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}
